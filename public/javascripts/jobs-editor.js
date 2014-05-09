
function show_job() {
    var html = '';
    var title = $('#job_title').val();
    if (title) {
        html = '<h2>' + title + '</h2>';
    }
    var description = $('#job_description').val();
    if (description) {
       html = markdown(description);
    }
    console.log(html);
    $('#job_post').html( html );
}

function show_error(txt) {
    console.log('Error: ' + txt);
}

function markdown(text) {
    return text;
}

function save_job() {
    console.log('save job');
    var title = $('#job_title').val();
	if (! title ) {
        show_error('Title is missing');
        return;
    }
}

function setup_jobs_editor() {
    console.log('setup starts 1');
    $("#job_save").click(save_job);
    $("#job_title").change(show_job);
    $("#job_title").keyup(show_job);
    console.log('setup ends');
}

setup_jobs_editor();

