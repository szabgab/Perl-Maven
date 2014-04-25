
function show_job() {
    var html = '';
    var title = document.getElementById('job_title').value;
    if (title) {
        html = '<h2>' + title + '</h2>';
    }
    
    console.log(html);
    document.getElementById('job-post').innerHTML = html;
}

function show_error(txt) {
    console.log('Error: ' + txt);
}

function save_job() {
    console.log('save job');
    var title = document.getElementById('job_title').value;
	if (! title ) {
        show_error('Title is missing');
        return;
    }
}

function setup_jobs_editor() {
    console.log('setup starts 1');
    $("#save").click(save_job);
    $("#job_title").change(show_job);
    $("#job_title").keyup(show_job);
    console.log('setup ends');
}

setup_jobs_editor();

