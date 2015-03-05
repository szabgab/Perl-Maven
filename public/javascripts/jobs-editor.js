
function collect_job_data() {
	var data = new Object;
	data["title"]             = $('#job-title').val();
	data["description"]       = $('#job-description').val();
	data["application-email"] = $('#job-application-email').val();
	data["application-url"]   = $('#job-application-url').val();
	data["on-site"]           = $('#job-on-site').is(':checked');
	data["city"]              = $('#job-city').val();
	data["state"]             = $('#job-state').val();
	data["country"]           = $('#job-country').val();
	data["company-name"]      = $('#job-company-name').val();
	data["company-url"]       = $('#job-company-url').val();

	return data;
}

function show_job() {
	var data = collect_job_data();

	var html = '';
	if (data["title"]) {
		html = '<h2>' + data["title"] + '</h2>';
	}
	if (data["description"]) {
		html += markdown(data["description"]);
	}

	if (data["application-email"]) {
		html += "<p>Apply by sending your CV to <b>" + data["application-email"] + "</b></p>";
	}
	if (data["application-url"]) {
		html += '<p>Apply by visiting <a href="' + data["application-url"] + '">here</a></p>';
	}

	if (data["on-site"]) {
		html += "<p>This is an on-site job at the following location:</p>";
	} else {
		html += "<p>This is a remote job, but if you want to visit, the offices of the company can be found here:</p>";
	}

	if (data["city"]) {
		html += '<p>City: ' + data["city"] + '</p>';
	}

	if (data["state"]) {
		html += '<p>State: ' + data["state"] + '</p>';
	}

	if (data["country"]) {
		html += '<p>Country: ' + data["country"] + '</p>';
	}

	if (data["company-name"] && data["company-url"]) {
		html += '<p>Company: <a href="' +  data["company-url"] + '">' + data["company-name"] + '</a></p>';
	} else if (data["company-name"]) {
		html += '<p>Company: ' +  data["company-name"] + '</p>';
	} else if (data["company-url"]) {
		html += '<p>Company: <a href="' +  data["company-url"] + '">' + data["company-url"] + '</a></p>';
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
	var data = collect_job_data();
	if (! data["title"] ) {
		show_error('Title is missing');
		return;
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

