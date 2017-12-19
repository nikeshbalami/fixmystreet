(function(){

if (!fixmystreet.maps) {
    return;
}

fixmystreet.maps.banes_map_options = function(typename, category, item) {
    return {
        http_options: {
            url: "https://isharemapstest.bathnes.gov.uk/getows.ashx",
            params: {
                mapsource: "BathNES/WFS",
                SERVICE: "WFS",
                VERSION: "1.1.0",
                REQUEST: "GetFeature",
                TYPENAME: typename,
                SRSNAME: "urn:ogc:def:crs:EPSG::27700"
            }
        },
        asset_category: category,
        asset_item: item,
        asset_type: 'spot',
        max_resolution: 2.388657133579254,
        min_resolution: 0.5971642833948135,
        asset_id_field: 'feature_no',
        attributes: {
            feature_id: 'feature_id'
        },
        geometryName: 'msGeometry',
        srsName: "EPSG:27700"
    };
};

$(fixmystreet.add_assets(fixmystreet.maps.banes_map_options("Gritbins", "Grit bin empty", "grit bin")));
$(fixmystreet.add_assets(fixmystreet.maps.banes_map_options("StreetLighting", "Street Light Fault", "street light")));

})();
