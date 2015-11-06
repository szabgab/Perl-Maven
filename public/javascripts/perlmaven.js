
// show the job posts one-by-one
// function show_jobs() {
//     //console.log('show_jobs');
// 	var done = false;
//     $('.featured_jobs').each(function() {
// 		if (done) {
// 			return;
// 		}
//         //console.log('show');
// 		//console.log( $(this).is(':visible') );
// 		if (! $(this).is(':visible') ) {
//             $(this).show();
// 			done = true;
// 	        setTimeout(show_jobs, 1000);
//             return;
//         }
// 		//console.log( $(this).is(':visible') );
//     });
// }

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

function admin_show_user_details(data, status, jqXHR) {
	//console.log(data);
	var html = '<table>';
	html += '<tr><td>email</td><td>timestamp</td><td>products</td></tr>';
	for (var i = 0; i < data['people'].length; i++) { 
		html += '<tr>';
        html += '<td>' + data['people'][i]['email'] + '</td>';
        html += '<td>' + new Date(data['people'][i]['verify_time'] * 1000) + '</td>';
		html += '<td>';
			for (var j=0; j < data['people'][i]['subscriptions'].length; j++) {
				html += data['people'][i]['subscriptions'][j] + '<br>';
			}
		html += '</td>'
		html += '</tr>';
	}
	$("#details").html(html);

}

$(document).ready(function() {
   $('#explain').click(code_explain);

	$(".archive-button").click(function (e) {
		//console.log( $('#abstract').attr('checked') );
	    show_archive(e.target.value, $('#abstract').is(':checked'));
		e.preventDefault();
	});
//	$('#abstract').attr('checked', );

 	$('#admin-search-email').keypress(function(e) {
 		$("#need-email").hide();
 	});
 
 	$('#admin-show-details').on('click', function(e) {
 		var email = $('#admin-search-email').val();
 		//console.log(email);
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
 

	$('a[href^="/pro\\/"]').each(function(i, e) {
		//console.log(this);
		//console.log( $(this).attr('href') );
		//console.log( $(this).html());
		$(this).html( $(this).html() + ' (pro)' );
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

	prettyPrint();
});
 
angular.module('PerlMavenApp', []);
angular.module('PerlMavenApp').controller('PerlMavenCtrl', function($scope, $http) {
    //console.log('start ng');
	$scope.search_index = function(word) {
		window.location.href = "/search/" + encodeURIComponent(word);
	};

	$scope.search = function() {
		//console.log('search');
		window.location.href = "/search/" + encodeURIComponent($scope.search_term);
    };
	$scope.autocomplete = function() {
		var query = $scope.search_term;
		//console.log('autocomplete "' + query + '"');
		// allow if it is a single character, as we would like to get suggestions on $ and -
		// but maybe disable if it is a letter or a digit.
		if (query.length < 1) {
			$scope.show_autocomplete = false; 
			return;
		}
		$http.get('/autocomplete.json/' + encodeURIComponent(query)).then(
                function(response) {
                    //console.log(response.data);
                    $scope.autocomplete_results = response.data;
					$scope.show_autocomplete = true;
					
                },
                function(response) {
                    console.log("error");
                }
        );
	};
});


