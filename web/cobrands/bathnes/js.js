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
            SRSNAME: "urn:ogc:def:crs:EPSG::27700"
        }
    },
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

$(fixmystreet.add_assets($.extend(true, {}, fixmystreet.maps.banes_defaults, {
    http_options: {
        params: {
            TYPENAME: "StreetLighting"
        }
    },
    asset_category: "Street Light Fault",
    asset_item: "street light"
})));

})();
