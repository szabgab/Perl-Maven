
var show_automatically = false;

// show the job posts one-by-one
function show_jobs() {
    //console.log('show_jobs');
	var done = false;
    $('.featured_jobs').each(function() {
		if (done) {
			return;
		}
        //console.log('show');
		//console.log( $(this).is(':visible') );
		if (! $(this).is(':visible') ) {
            $(this).show();
			done = true;
	        setTimeout(show_jobs, 1000);
            return;
        }
		//console.log( $(this).is(':visible') );
    });
}

function mysearch(keyword, auto) {
    if (keyword) {
        window.location = '/search/' + keyword;
    }
    return;

    var url = '/search.json';
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
        $.ajax({
           url: '/modal/' + user_info['delayed']['what'],
           dataType: "html",
           success: function(data, status, jqXHR) {
               $("#modal").html(data);
		       setTimeout(function () {$( '#' + user_info['delayed']['what'] ).modal('show')} , user_info['delayed']['when'] );
           },
        });
	}
}

function admin_show_user_details(data, status, jqXHR) {
	//console.log(data);
	var html = '<table>';
	html += '<tr><td>email</td><td>timestamp</td><td>products</td></tr>';
	for (var i = 0; i < data['people'].length; i++) { 
		html += '<tr>';
        html += '<td>' + data['people'][i]['email'] + '</td>';
        //html += '<td>' + new Date(data['people'][i]['verify_time']) + '</td>';
        html += '<td>' + data['people'][i]['verify_time'] + '</td>';
		html += '<td>';
			for (var j=0; j < data['people'][i]['subscriptions'].length; j++) {
				html += data['people'][i]['subscriptions'][j] + '<br>';
			}
		html += '</td>'
		html += '</tr>';
	}
	$("#details").html(html);

}

function setup_search (query, process) {
	//console.log('setup');

    $.ajax({
        url: '/search.json',
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
    if (data['perl_maven_pro']) {
		$('#popup_logged_in').modal('show');
		$('#just-register-message').html('Thank you for registering!');
	} else {
		$('#popup_thank_you').modal('show');
	}
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

//	$('#search_box').typeahead( { 'source' : setup_search, items : 20  });
//	$('#search_box').blur(function (e) {
//		// This delay is a work-around to let the JS fill the input box before we grab the value from there.
//		// In later versions of Bootstrap there is probably a better solution for this
//		setTimeout(function() {
//			var keyword = $("#search_box").val();
//			//console.log('click:' + keyword);
//			mysearch(keyword, true);
//		}, 100);
//	});

 	$("#search_box").keyup(function (e) {
       var query = $("#search_box").val();

       $.ajax({
           url: '/search.json',
           data: { 'query' :  query},
           dataType: "json",
           success: function(data, status, jqXHR) {
              //console.log('callback');
              var html = '<h2>Searching for <span id="term">' + query + '</span></h2>';
              html += '<ul>';
              var i;
              for (i=0; i < data.length; i++) {
                  html += '<li><a href="/search/' + data[i] + '">' + data[i] + '</a></li>';
              }
              html += '</ul>';
              $("#content").html(html);
              //console.log(data);
	       },
       });
       return;
    });

// 	$("#search_box").keyup(function (e) {
// 	    if (e.keyCode == 13) {
// 	        var keyword = $("#search_box").val();
// 	        mysearch(keyword, true);
// 		}
// 	});
// 
// 	$('#email').keypress(function(e) {
// 		$("#need-email").hide();
// 	});
// 
// 	$('#admin-show-details').on('click', function(e) {
// 		var email = $('#email').val();
// 		//console.log(email);
// 		if (! email) {
// 			//console.log('alert');
// 			$("#need-email").show();
// 			return false;
// 		}
//     	$.ajax({
//         	url: '/admin/user_info.json',
//         	data: { "email" : email },
//         	dataType: "json",
//         	success: admin_show_user_details,
//     	});
// 
// 		return false;
// 	});
// 
// 	$('#register-button').on('click', function(e) {
// 		var name = $('#register-name').val();
// 		var email = $('#register-email').val();
// 		var password = $('#register-password').val();
// 		//console.log(email);
// 		// TODO validate before submit
// 		$('#register-message').html('');
// 	    $.ajax({
//             url: '/pm/register.json',
//             type: 'POST',
//             data: {"name" : name, "email" : email, "password" : password},
//             dataType: "json",
//             success: register_result,
//         });
// 	});
// 
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

    $('.spoiler').on('click', function(e) {
        if ($(this).hasClass('spoiler_hidden')) {
            $(this).html($(this).attr('content'));
            $(this).removeClass('spoiler_hidden');
            $(this).addClass('spoiler_spoiled');
        } else {
            $(this).html($(this).attr('text'));
            $(this).removeClass('spoiler_spoiled');
            $(this).addClass('spoiler_hidden');
        }
    });
    $('.spoiler').each(function () {
        $(this).attr('content', $(this).html());
        $(this).addClass('spoiler_spoiled');
        $(this).trigger('click');
    
    });

	setTimeout(show_jobs, 1000);

	prettyPrint();
});
 
