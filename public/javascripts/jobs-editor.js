
function show_job() {
    var html = '';
    var title = $('#job-title').val();
    if (title) {
        html = '<h2>' + title + '</h2>';
    }
    var description = $('#job-description').val();
    if (description) {
       html = markdown(description);
    }
    //console.log(html);
    $('#job-post').html( html );
    $('#job-error').html( '' );
}

function show_error(txt) {
	var html = '<div class="alert alert-danger" role="alert">' + txt + '</div>';
    $('#job-error').html( html );
}

function markdown(text) {
    return text;
}

function save_job_result(data, status, jqXHR) {
	console.log(data);
	if (data["ok"]) {
		$("#job-editor").hide();
    	$('#job-error').html( '' );
    	$('#job-post').html( 'Job post saved. <a href="/pm/jobs">List jobs</a>' );
		return;
	}
	if (data["error"]) {
        show_error(data["error"]);
		return;
	}

    show_error("Unknown response");
	return;
}

function save_job(e) {
	e.preventDefault();
    //console.log('save job');
    var title = $('#job-title').val();
	if (! title ) {
        show_error('Title is missing');
        return;
    }
	var data = {
		'title' : title,
	}
    $.ajax({
        url: '/pm/jobs/save.json',
        data: data,
        dataType: "json",
        success: save_job_result,
    });
}

function setup_jobs_editor() {
    $("#job-save").click(save_job);
    $("#job-title").change(show_job);
    $("#job-title").keyup(show_job);
}

setup_jobs_editor();

