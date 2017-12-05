(function(){

if (!fixmystreet.maps) {
    return;
}

$(fixmystreet.add_assets({
    http_options: {
        url: "https://isharemapstest.bathnes.gov.uk/getows.ashx",
        params: {
            mapsource: "BathNES/WFS",
            SERVICE: "WFS",
            VERSION: "1.1.0",
            REQUEST: "GetFeature",
            TYPENAME: "Gritbins",
            SRSNAME: "urn:ogc:def:crs:EPSG::27700"
        }
    },
    asset_category: "Grit Bins",
    asset_item: 'grit bin',
    asset_type: 'spot',
    max_resolution: 2.388657133579254,
    min_resolution: 0.5971642833948135,
    asset_id_field: 'feature_no',
    attributes: {
        feature_id: 'feature_id'
    },
    geometryName: 'msGeometry',
    srsName: "EPSG:27700"
}));

$(fixmystreet.add_assets({
    http_options: {
        url: "https://isharemapstest.bathnes.gov.uk/getows.ashx",
        params: {
            mapsource: "BathNES/WFS",
            SERVICE: "WFS",
            VERSION: "1.1.0",
            REQUEST: "GetFeature",
            TYPENAME: "StreetLighting",
            SRSNAME: "urn:ogc:def:crs:EPSG::27700"
        }
    },
    asset_category: "Street Light Fault",
    asset_item: 'street light',
    asset_type: 'spot',
    max_resolution: 2.388657133579254,
    min_resolution: 0.5971642833948135,
    asset_id_field: 'feature_no',
    attributes: {
        feature_id: 'feature_id'
    },
    geometryName: 'msGeometry',
    srsName: "EPSG:27700"
}));

})();
