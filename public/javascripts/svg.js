
/*
function draw_perl_xml(data, status, jqXHR) {
    console.log('draw' + data);
    var draw_div = document.getElementById('svg-xml');
    draw_div.innerHTML = data;
}
function fetch_perl_xml() {
    var url = '/svg.xml';
    var data = $('#form').serialize();
    $.ajax({
        url: url,
        data: data,
        success: draw_perl_xml,
//        dataType: 'xml',
    });
}
//var draw_button = document.getElementById('draw');
//draw_button.addEventListener('click', fetch_perl_xml );
//console.log(draw_button);

*/

function draw_xml() {
    var header = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        + '<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.0//EN" "http://www.w3.org/TR/2001/REC-SVG-20010904/DTD/svg10.dtd">\n';

    var svg_start = '<svg xmlns="http://www.w3.org/2000/svg" xmlns:svg="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink"';
    //should be height and width
    $('#image').find("input").each(function(index, field) {
            svg_start += ' ' + field.name + '="' + field.value + '"';
    });
    svg_start += '>\n';
    var svg_end = '</svg>\n';

    var data = '<rect';
    $('#form').find("input").each(function(index, field) {
        if (field.name != '') {
            //console.log(index + ' ' + field.name + ' ' + field.value);
            data += ' ' + field.name + '="' + field.value + '"';
        }
    })
    data += ' />\n';

    var xml = svg_start + data + svg_end;
    //console.log(xml);
    $("#svg-xml").html(xml);
    $("#source-code").val(header + '\n' + xml);
    return false;
}

$(document).ready(function() {
    draw_xml();
    $("#draw").click(draw_xml);
});

