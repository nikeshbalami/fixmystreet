(function(){

if (!fixmystreet.maps) {
    return;
}

fixmystreet.maps.banes_defaults = {
    http_options: {
        url: "https://isharemapstest.bathnes.gov.uk/getows.ashx",
        // url: "https://confirmdev.eu.ngrok.io/banesmaps/getows.ashx",
        params: {
            mapsource: "BathNES/WFS",
            SERVICE: "WFS",
            VERSION: "1.1.0",
            REQUEST: "GetFeature",
            TYPENAME: "",
            SRSNAME: "urn:ogc:def:crs:EPSG::27700",
            outputFormat: 'application/json'
        },
        format_class: OpenLayers.Format.GeoJSON,
        format_options: {ignoreExtraDims: true}
    },
    strategy_class: OpenLayers.Strategy.FixMyStreet,
    asset_category: "",
    asset_item: "asset",
    asset_type: 'spot',
    max_resolution: 2.388657133579254,
    min_resolution: 0.5971642833948135,
    asset_id_field: 'feature_no',
    attributes: null,
    geometryName: 'msGeometry',
    srsName: "EPSG:27700"
};


$(fixmystreet.add_assets($.extend(true, {}, fixmystreet.maps.banes_defaults, {
    http_options: {
        params: {
            TYPENAME: "Gritbins"
        }
    },
    asset_category: "Grit bin issue",
    asset_item: "grit bin"
})));


function banes_owns_feature(f) {
    return f &&
           f.attributes &&
           f.attributes.ownername &&
           f.attributes.ownername.match &&
           f.attributes.ownername.match(/B&NES/);
}

function banes_does_not_own_feature(feature) {
    return !banes_owns_feature(feature);
}

var lighting_default_style = new OpenLayers.Style({
    fillColor: "#868686",
    fillOpacity: 0.6,
    strokeColor: "#000000",
    strokeOpacity: 0.6,
    strokeWidth: 2,
    pointRadius: 4,
    title: 'Not owned by B&NES. Owned by ${ownername}.'
});

var rule_owned = new OpenLayers.Rule({
    filter: new OpenLayers.Filter.FeatureId({
        type: OpenLayers.Filter.Function,
        evaluate: banes_owns_feature
    }),
    symbolizer: {
        fillColor: "#FFFF00",
        pointRadius: 6,
        title: '${unitdescription} ${unitno}',
    }
});

var rule_not_owned = new OpenLayers.Rule({
    filter: new OpenLayers.Filter.FeatureId({
        type: OpenLayers.Filter.Function,
        evaluate: banes_does_not_own_feature
    })
});
lighting_default_style.addRules([rule_owned, rule_not_owned]);

// XXX fixmystreet.pin_prefix isn't always available here (e.g. on /report/new),
// so get it from the DOM directly
var pin_prefix = fixmystreet.pin_prefix || document.getElementById('js-map-data').getAttribute('data-pin_prefix');

var lighting_stylemap = new OpenLayers.StyleMap({
    'default': lighting_default_style,
    'select': new OpenLayers.Style({
        externalGraphic: pin_prefix + "pin-spot.png",
        fillColor: "#55BB00",
        graphicWidth: 48,
        graphicHeight: 64,
        graphicXOffset: -24,
        graphicYOffset: -56,
        backgroundGraphic: pin_prefix + "pin-shadow.png",
        backgroundWidth: 60,
        backgroundHeight: 30,
        backgroundXOffset: -7,
        backgroundYOffset: -22,
        popupYOffset: -40,
        graphicOpacity: 1.0
    }),
    'hover': new OpenLayers.Style({
        pointRadius: 8,
        cursor: 'pointer'
    })

});


$(fixmystreet.add_assets($.extend(true, {}, fixmystreet.maps.banes_defaults, {
    http_options: {
        params: {
            TYPENAME: "StreetLighting"
        }
    },
    asset_category: "Street Light Fault",
    asset_item: "street light",
    stylemap: lighting_stylemap,
    attributes: {
        unitid: "unitid",
        asset_details: function() {
            var a = this.attributes;
            return "street: " + a.street + "\n" +
                   "owner: " + a.ownername + "\n" +
                   "unitno: " + a.unitno + "\n" +
                   "lamp: " + a.lamp + "\n" +
                   "lampclass: " + a.lampclass + "\n" +
                   "description: " + a.unitdescription;
        }
    }
})));

})();
