
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

function show_archive(tag, show_abstract) {
    //console.log(window.location);
    var url = window.location.origin + window.location.pathname + '?';
	var fields = new Array;
	if (tag) {
		fields.push('tag=' + tag);
	}
	if (show_abstract) {
		fields.push('abstract=1');
	}
	//console.log(fields);
    url += fields.join('&');
	//console.log(url);
    window.location = url;
}

function code_explain() {
    var code = $('#code').val();
    var data = { "code" : code };
    //$('#result').slideToggle('fast', function() {});
    $('#result').show('fast', function() {});

    $('#code_echo').empty();
	$('#explanation').empty();
	$('#ppi_explain').empty();
	$('#ppi_dump').empty();

    var code_html = code;
    code_html = code_html.replace(/</g, "&lt;");
    code_html = code_html.replace(/>/g, "&gt;");
    $('#code_echo').append('<pre>' + code_html + '</pre>');
	$.post("/explain", data, function(resp) {
		//console.log('success');
		//console.log(resp);
		var data = jQuery.parseJSON(resp);

    	$('#explanation').append(data["explanation"]);

        var ppi_dump = data["ppi_dump"].join("\n");
    	$('#ppi_dump').append('<pre>' + ppi_dump  + '</pre>');

        var ppi_explain = '';
		for(var i=0; i < data["ppi_explain"].length; i++) {
			ppi_explain += '<b>' + data["ppi_explain"][i]["code"] + '</b>';
			ppi_explain += data["ppi_explain"][i]["text"] + '<br>'; 
		}
    	$('#ppi_explain').append(ppi_explain);
	}).fail(function() {
		//console.log('fail');
		alert('fail');
	});
    //alert($('#code').val());
}

function show_user_info() {
	if ('delayed' in user_info) {
		setTimeout(function () {$( '#' + user_info['delayed']['what'] ).modal('show')} , user_info['delayed']['when'] );
	}
}

function admin_show_user_details(data, status, jqXHR) {
	//console.log(data);
	var html = '<table>';
	html += '<tr><td>email</td><td>timestamp</td><td>products</td></tr>';
	for (var i = 0; i < data['people'].length; i++) { 
		html += '<tr>';
        html += '<td>' + data['people'][i][1] + '</td>';
        html += '<td>' + new Date(data['people'][i][2] * 1000) + '</td>';
		html += '<td>';
			for (var j=0; j < data['people'][i][3].length; j++) {
				html += data['people'][i][3][j] + '<br>';
			}
		html += '</td>'
		html += '</tr>';
	}
	$("#details").html(html);

}

function setup_search (query, process) {
	//console.log('setup');

    $.ajax({
        url: '/search',
        data: { 'query' :  query},
        dataType: "json",
        success: function(data, status, jqXHR) {
           //console.log('callback');
           process(data);
	    },
    });

    return;
}

$(document).ready(function() {
    $('#explain').click(code_explain);
    show_user_info();

	$(".archive-button").click(function (e) {
		//console.log( $('#abstract').attr('checked') );
	    show_archive(e.target.value, $('#abstract').is(':checked'));
		e.preventDefault();
	});
//	$('#abstract').attr('checked', );

	$(".kw-button").click(function (e) {
	    mysearch(e.target.value, false);
	});

	$('#typeahead').typeahead( { 'source' : setup_search, items : 20  });

	$("#typeahead").keyup(function (e) {
	    if (e.keyCode == 13) {
	        var keyword = $("#typeahead").val();

	        mysearch(keyword, true);
		}
	});

	$('#email').keypress(function(e) {
		$("#need-email").hide();
	});

	$('#admin-show-details').on('click', function(e) {
		var email = $('#email').val();
		console.log(email);
		if (! email) {
			//console.log('alert');
			$("#need-email").show();
			return false;
		}
    	$.ajax({
        	url: '/admin/user_info',
        	data: { "email" : email },
        	dataType: "json",
        	success: admin_show_user_details,
    	});

		return false;
	});

	$('a[href^="/pro\\/"]').each(function(i, e) {
		//console.log(this);
		//console.log( $(this).attr('href') );
		//console.log( $(this).html());
		$(this).html( $(this).html() + ' (pro)' );
	});
//	$("a").click(function (e) {
//		e.preventDefault();
//		console.log('click' + e);
//		console.log(this);
//		console.log($(this).attr('href'));
//	});


});

