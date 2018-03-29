// show the job posts one-by-one
// function show_jobs() {
//     //console.log('show_jobs');
//     var done = false;
//     $('.featured_jobs').each(function() {
//         if (done) {
//             return;
//         }
//         //console.log('show');
//         //console.log( $(this).is(':visible') );
//         if (! $(this).is(':visible') ) {
//             $(this).show();
//             done = true;
//             setTimeout(show_jobs, 1000);
//             return;
//         }
//         //console.log( $(this).is(':visible') );
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
    var data = {
        "code": code
    };
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
        $('#ppi_dump').append('<pre>' + ppi_dump + '</pre>');

        var ppi_explain = '';
        for (var i = 0; i < data["ppi_explain"].length; i++) {
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

$(document).ready(function() {
    $('#explain').click(code_explain);

    if (top_poster) {
        $('#top-poster').html(top_poster);
        $('#top-poster').show();
        //$('#top-poster').css('display', 'block');
    }

    $(".archive-button").click(function(e) {
        //console.log( $('#abstract').attr('checked') );
        show_archive(e.target.value, $('#abstract').is(':checked'));
        e.preventDefault();
    });
    //    $('#abstract').attr('checked', );
    $('a[href^="/pro\\/"]').each(function(i, e) {
        //console.log(this);
        //console.log( $(this).attr('href') );
        //console.log( $(this).html());
        $(this).html($(this).html() + ' (pro)');
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
    $('.spoiler').each(function() {
        $(this).attr('content', $(this).html());
        $(this).addClass('spoiler_spoiled');
        $(this).trigger('click');

    });

	$('#search_box').keypress(function (e) {
		//console.log('click', e, new Date);
		var word = $('#search_box').val();
		word = $.trim( word );
		//console.log("'" + word + "'");
		if (word === '') {
			return;
		}
		if (e.key === 'Enter') {
			console.log('enter', word);
        	window.location.href = "/search/" + encodeURIComponent(word);
			return false;
		} else {
			// we can implement the autocomplete here if it is a good idea
		}
	});

    //prettyPrint();
});


