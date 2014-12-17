
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
       $('#search_results').html('Not found');
       $('#popup_search_results').modal('show')
    } else if (count == 1 && show_automatically) {
       window.location = single;
    } else {
       $('#search_results').html(html);
       $('#popup_search_results').modal('show')
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

function register_result (data, status, jqXHR) {
	//console.log(data);
	if (data['error']) {
		$('#register-message').html(data['error']);
		return;
	}

	// success:
	$('#popup_visitor').modal('hide');
	$('#popup_logged_in').modal('show');
	$('#just-register-message').html('Thank you for registering!');
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

	$('#search_box').typeahead( { 'source' : setup_search, items : 20  });
	$('#search_box').blur(function (e) {
		// This delay is a work-around to let the JS fill the input box before we grab the value from there.
		// In later versions of Bootstrap there is probably a better solution for this
		setTimeout(function() {
			var keyword = $("#search_box").val();
			//console.log('click:' + keyword);
			mysearch(keyword, true);
		}, 100);
	});

	$("#search_box").keyup(function (e) {
	    if (e.keyCode == 13) {
	        var keyword = $("#search_box").val();
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
        	url: '/admin/user_info.json',
        	data: { "email" : email },
        	dataType: "json",
        	success: admin_show_user_details,
    	});

		return false;
	});

	$('#register-button').on('click', function(e) {
		var name = $('#register-name').val();
		var email = $('#register-email').val();
		var password = $('#register-password').val();
		//console.log(email);
		// TODO validate before submit
		$('#register-message').html('');
	    $.ajax({
            url: '/pm/register.json',
            type: 'POST',
            data: {"name" : name, "email" : email, "password" : password},
            dataType: "json",
            success: register_result,
        });
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

	$('#free-button').on('click', function(e) {
		$('#popup_visitor').modal('show');
	});
	$('#pro-button').on('click', function(e) {
		$('#popup_logged_in').modal('show');
	});

	prettyPrint();
});

