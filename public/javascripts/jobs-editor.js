
function show_job() {
    var html = '';
    var title = $('#job-title').val();
    if (title) {
        html = '<h2>' + title + '</h2>';
    }
    var description = $('#job-description').val();
    if (description) {
       html += markdown(description);
    }

	var email = $('#application-email').val();
	if (email) {
		html += "<p>Apply by sending your CV to <b>" + email + "</b></p>";
	}
	var url = $('#application-url').val();
	if (url) {
		html += '<p>Apply by visiting <a href="' + url + '">here</a></p>';
	}

	var on_site = $('#job-on-site').is(':checked');
	if (on_site) {
		html += "<p>This is an on-site job at the following location:</p>";
	} else {
		html += "<p>This is a remote job, but if you want to visit, the offices of the company can be found here:</p>";
	}

	var job_city = $('#job-city').val();
	if (job_city) {
		html += '<p>City: ' + job_city + '</p>';
	}

	var job_state = $('#job-state').val();
	if (job_state) {
		html += '<p>State: ' + job_state + '</p>';
	}

	var job_country = $('#job-country').val();
	if (job_country) {
		html += '<p>Country: ' + job_country + '</p>';
	}

	var company_name = $('#company-name').val();
	var company_url = $('#company-url').val();
	if (company_name && company_url) {
		html += '<p>Company: <a href="' +  company_url + '">' + company_name + '</a></p>';
	} else if (company_name) {
		html += '<p>Company: ' +  company_name + '</p>';
	} else if (company_url) {
		html += '<p>Company: <a href="' +  company_url + '">' + company_url + '</a></p>';
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
    return '<p>' + text + '</p>';
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
    $("input").change(show_job);
    $("input").keyup(show_job);
    $("input").click(show_job);
    $("textarea").change(show_job);
    $("textarea").keyup(show_job);
}

setup_jobs_editor();

