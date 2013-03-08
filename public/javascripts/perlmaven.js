function mysearch(keyword, auto) {
    var count = 0;

    var single;
    var html = '<ul>';
    for (var prop in data[ keyword ] ) {
        count++;
        single = '/' + prop;
        html += '<li><a href="/' + prop + '">';
        html += data[keyword][prop] + '</a></li>';
    }
    html += '</ul>';
    //console.log(count);
    if (count == 1 && auto) {
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

