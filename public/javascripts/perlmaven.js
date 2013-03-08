
var show_automatically = false;

function mysearch(keyword, auto) {
    var url = '/search';
    show_automatically = auto;
    var data = {
        "keyword" : keyword,
    };
    $.ajax({
        url: url,
        data: data,
        dataType: "json",
        success: display_search_result,
    });
}

function display_search_result(data, status, jqXHR) {
    var count = 0;

    //console.log(data);

    var single;
    var html = '<ul>';
    for (var prop in data ) {
        count++;
        single = '/' + prop;
        html += '<li><a href="/' + prop + '">';
        html += data[prop] + '</a></li>';
    }
    html += '</ul>';
    //console.log(count);
    if (count == 0) {
       $('.modal-body').html('Not found');
       $('#myModal').modal('show')
    } else if (count == 1 && show_automatically) {
       window.location = single;
    } else {
       $('.modal-body').html(html);
       $('#myModal').modal('show')
    }
}

$(".kw-button").click(function (e) {
    mysearch(e.target.value, false);
});

$("#typeahead").keyup(function (e) {
    if (e.keyCode == 13) {
        //console.log('----------');
        var keyword = $("#typeahead").val();

        mysearch(keyword, true);
    }
});

