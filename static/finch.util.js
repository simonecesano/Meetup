// foo

Finch.build = function(template, vars){
    return template.split('/').map(function(e, i){
	if (e.match(/^:(.+)/)) {
	    var m = e.match(/^:(.+)/);
	    e = vars[m[1]] === undefined ? e : vars[m[1]];
	    return e
	} else {
	    return e
	}
    }).join('/')
}
