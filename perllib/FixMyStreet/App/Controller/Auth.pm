package FixMyStreet::App::Controller::Auth;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

use Email::Valid;
use Digest::HMAC_SHA1 qw(hmac_sha1);
use JSON::MaybeXS;
use MIME::Base64;

=head1 NAME

FixMyStreet::App::Controller::Auth - Catalyst Controller

=head1 DESCRIPTION

Controller for all the authentication related pages - create account, sign in,
sign out.

=head1 METHODS

=head2 index

Present the user with a sign in / create account page.

=cut

sub general : Path : Args(0) {
    my ( $self, $c ) = @_;

    $c->detach( 'redirect_on_signin', [ $c->get_param('r') ] )
        if $c->req->method eq 'GET' && $c->user && $c->get_param('r');

    # all done unless we have a form posted to us
    return unless $c->req->method eq 'POST';

    my $clicked_email = $c->get_param('email_sign_in');
    my $data_address = $c->get_param('email');
    my $data_password = $c->get_param('password_sign_in');
    my $data_email = $c->get_param('name') || $c->get_param('password_register');

    # decide which action to take
    $c->detach('email_sign_in') if $clicked_email || ($data_email && !$data_password);
    if (!$data_address && !$data_password && !$data_email) {
        $c->detach('social/facebook_sign_in') if $c->get_param('facebook_sign_in');
        $c->detach('social/twitter_sign_in') if $c->get_param('twitter_sign_in');
    }

       $c->forward( 'sign_in' )
    && $c->detach( 'redirect_on_signin', [ $c->get_param('r') ] );

}

sub general_test : Path('_test_') : Args(0) {
    my ( $self, $c ) = @_;
    $c->stash->{template} = 'auth/token.html';
}

=head2 sign_in

Allow the user to sign in with a username and a password.

=cut

sub sign_in : Private {
    my ( $self, $c, $email ) = @_;

    $email ||= $c->get_param('email') || '';
    $email = lc $email;
    my $password = $c->get_param('password_sign_in') || '';
    my $remember_me = $c->get_param('remember_me') || 0;

    # Sign out just in case
    $c->logout();

    if (   $email
        && $password
        && $c->authenticate( { email => $email, email_verified => 1, password => $password } ) )
    {

        # unless user asked to be remembered limit the session to browser
        $c->set_session_cookie_expire(0)
          unless $remember_me;

        # Regenerate CSRF token as session ID changed
        $c->forward('get_csrf_token');

        return 1;
    }

    $c->stash(
        sign_in_error => 1,
        email => $email,
        remember_me => $remember_me,
    );
    return;
}

=head2 email_sign_in

Email the user the details they need to sign in. Don't check for an account - if
there isn't one we can create it when they come back with a token (which
contains the email address).

=cut

sub email_sign_in : Private {
    my ( $self, $c ) = @_;

    # check that the email is valid - otherwise flag an error
    my $raw_email = lc( $c->get_param('email') || '' );

    my $email_checker = Email::Valid->new(
        -mxcheck  => 1,
        -tldcheck => 1,
        -fqdn     => 1,
    );

    my $good_email = $email_checker->address($raw_email);
    if ( !$good_email ) {
        $c->stash->{email} = $raw_email;
        $c->stash->{email_error} =
          $raw_email ? $email_checker->details : 'missing';
        return;
    }

    # If user registration is disabled then bail out at this point
    # if there's not already a user with this email address.
    # NB this uses the same template as a successful sign in to stop
    # enumeration of valid email addresses.
    if ( FixMyStreet->config('SIGNUPS_DISABLED')
         && !$c->model('DB::User')->search({ email => $good_email })->count
         && !$c->stash->{current_user} # don't break the change email flow
    ) {
        $c->stash->{template} = 'auth/token.html';
        return;
    }

    my $user_params = {};
    $user_params->{password} = $c->get_param('password_register')
        if $c->get_param('password_register');
    my $user = $c->model('DB::User')->new( $user_params );

    my $token_data = {
        email => $good_email,
        r => $c->get_param('r'),
        name => $c->get_param('name'),
        password => $user->password,
    };
    $token_data->{facebook_id} = $c->session->{oauth}{facebook_id}
        if $c->get_param('oauth_need_email') && $c->session->{oauth}{facebook_id};
    $token_data->{twitter_id} = $c->session->{oauth}{twitter_id}
        if $c->get_param('oauth_need_email') && $c->session->{oauth}{twitter_id};
    if ($c->stash->{current_user}) {
        $token_data->{old_email} = $c->stash->{current_user}->email;
        $token_data->{r} = 'auth/change_email/success';
    }

    my $token_obj = $c->model('DB::Token')->create({
        scope => 'email_sign_in',
        data  => $token_data,
    });

    $c->stash->{token} = $token_obj->token;
    my $template = $c->stash->{email_template} || 'login.txt';
    $c->send_email( $template, { to => $good_email } );
    $c->stash->{template} = 'auth/token.html';
}

=head2 token

Handle the 'email_sign_in' tokens. Find the account for the email address
(creating if needed), authenticate the user and delete the token.

=cut

sub token : Path('/M') : Args(1) {
    my ( $self, $c, $url_token ) = @_;

    # retrieve the token or return
    my $token_obj = $url_token
      ? $c->model('DB::Token')->find( {
          scope => 'email_sign_in', token => $url_token
        } )
      : undef;

    if ( !$token_obj ) {
        $c->stash->{token_not_found} = 1;
        return;
    }

    if ( $token_obj->created < DateTime->now->subtract( days => 1 ) ) {
        $c->stash->{token_not_found} = 1;
        return;
    }

    # find or create the user related to the token.
    my $data = $token_obj->data;

    if ($data->{old_email} && (!$c->user_exists || $c->user->email ne $data->{old_email})) {
        $c->stash->{token_not_found} = 1;
        return;
    }

    # sign out in case we are another user
    $c->logout();

    my $user = $c->model('DB::User')->find_or_new({ email => $data->{email} });

    # Bail out if this is a new user and SIGNUPS_DISABLED is set
    $c->detach( '/page_error_403_access_denied', [] )
        if FixMyStreet->config('SIGNUPS_DISABLED') && !$user->in_storage && !$data->{old_email};

    if ($data->{old_email}) {
        # Were logged in as old_email, want to switch to email ($user)
        if ($user->in_storage) {
            my $old_user = $c->model('DB::User')->find({ email => $data->{old_email} });
            if ($old_user) {
                $old_user->adopt($user);
                $user = $old_user;
                $user->email($data->{email});
            }
        } else {
            # Updating to a new (to the db) email address, easier!
            $user = $c->model('DB::User')->find({ email => $data->{old_email} });
            $user->email($data->{email});
        }
    }

    $user->name( $data->{name} ) if $data->{name};
    $user->password( $data->{password}, 1 ) if $data->{password};
    $user->facebook_id( $data->{facebook_id} ) if $data->{facebook_id};
    $user->twitter_id( $data->{twitter_id} ) if $data->{twitter_id};
    $user->update_or_insert;
    $c->authenticate( { email => $user->email, email_verified => 1 }, 'no_password' );

    # send the user to their page
    $c->detach( 'redirect_on_signin', [ $data->{r}, $data->{p} ] );
}

=head2 redirect_on_signin

Used after signing in to take the person back to where they were.

=cut


sub redirect_on_signin : Private {
    my ( $self, $c, $redirect, $params ) = @_;
    unless ( $redirect ) {
        $c->detach('redirect_to_categories') if $c->user->from_body && scalar @{ $c->user->categories };
        $redirect = 'my';
    }
    $redirect = 'my' if $redirect =~ /^admin/ && !$c->cobrand->admin_allow_user($c->user);
    if ( $c->cobrand->moniker eq 'zurich' ) {
        $redirect = 'admin' if $c->user->from_body;
    }
    if (defined $params) {
        $c->res->redirect( $c->uri_for( "/$redirect", $params ) );
    } else {
        $c->res->redirect( $c->uri_for( "/$redirect" ) );
    }
}

=head2 redirect_to_categories

Redirects the user to their body's reports page, prefiltered to whatever
categories this user has been assigned to.

=cut

sub redirect_to_categories : Private {
    my ( $self, $c ) = @_;

    my $categories = join(',', @{ $c->user->categories });
    my $body_short = $c->cobrand->short_name( $c->user->from_body );

    $c->res->redirect( $c->uri_for( "/reports/" . $body_short, { filter_category => $categories } ) );
}

=head2 redirect

Used when trying to view a page that requires sign in when you're not.

=cut

sub redirect : Private {
    my ( $self, $c ) = @_;

    my $uri = $c->uri_for( '/auth', { r => $c->req->path } );
    $c->res->redirect( $uri );
    $c->detach;

}

sub get_csrf_token : Private {
    my ( $self, $c ) = @_;

    my $time = $c->stash->{csrf_time} || time();
    my $hash = hmac_sha1("$time-" . ($c->sessionid || ""), $c->model('DB::Secret')->get);
    $hash = encode_base64($hash, "");
    $hash =~ s/=$//;
    my $token = "$time-$hash";
    $c->stash->{csrf_token} = $token unless $c->stash->{csrf_time};
    return $token;
}

sub check_csrf_token : Private {
    my ( $self, $c ) = @_;

    my $token = $c->get_param('token') || "";
    $token =~ s/ /+/g;
    my ($time) = $token =~ /^(\d+)-[0-9a-zA-Z+\/]+$/;
    $c->stash->{csrf_time} = $time;
    my $gen_token = $c->forward('get_csrf_token');
    delete $c->stash->{csrf_time};
    $c->detach('no_csrf_token')
        unless $time
            && $time > time() - 3600
            && $token eq $gen_token;
}

sub no_csrf_token : Private {
    my ($self, $c) = @_;
    $c->detach('/page_error_400_bad_request', []);
}

=head2 sign_out

Log the user out. Tell them we've done so.

=cut

sub sign_out : Local {
    my ( $self, $c ) = @_;
    $c->logout();
}

sub ajax_sign_in : Path('ajax/sign_in') {
    my ( $self, $c ) = @_;

    my $return = {};
    if ( $c->forward( 'sign_in' ) ) {
        $return->{name} = $c->user->name;
    } else {
        $return->{error} = 1;
    }

    my $body = encode_json($return);
    $c->res->content_type('application/json; charset=utf-8');
    $c->res->body($body);

    return 1;
}

sub ajax_sign_out : Path('ajax/sign_out') {
    my ( $self, $c ) = @_;

    $c->logout();

    my $body = encode_json( { signed_out => 1 } );
    $c->res->content_type('application/json; charset=utf-8');
    $c->res->body($body);

    return 1;
}

sub ajax_check_auth : Path('ajax/check_auth') {
    my ( $self, $c ) = @_;

    my $code = 401;
    my $data = { not_authorized => 1 };

    if ( $c->user ) {
        $data = { name => $c->user->name };
        $code = 200;
    }

    my $body = encode_json($data);
    $c->res->content_type('application/json; charset=utf-8');
    $c->res->code($code);
    $c->res->body($body);

    return 1;
}

=head2 check_auth

Utility page - returns a simple message 'OK' and a 200 response if the user is
authenticated and a 'Unauthorized' / 401 reponse if they are not.

Mainly intended for testing but might also be useful for ajax calls.

=cut

sub check_auth : Local {
    my ( $self, $c ) = @_;

    # choose the response
    my ( $body, $code )    #
      = $c->user
      ? ( 'OK', 200 )
      : ( 'Unauthorized', 401 );

    # set the response
    $c->res->body($body);
    $c->res->code($code);

    # NOTE - really a 401 response should also contain a 'WWW-Authenticate'
    # header but we ignore that here. The spec is not keeping up with usage.

    return;
}

__PACKAGE__->meta->make_immutable;

1;
