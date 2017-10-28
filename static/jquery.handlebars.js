(function ( $ ) {
    var templates = {};

    $(function(){
	$(window.document.body).find("[type='text/x-handlebars-template']").each(function(){
	    var id = $(this).attr('id').replace(/\W*template/i, '').replace(/\W+/, '_')
	    templates[id] = Handlebars.compile($(this).html());
	})
    });

    $.fn.fromTemplate = function(templateName, data){
	var t = templates[templateName];
	if (t === undefined){
	    t = Handlebars.compile($('#' + templateName + '-template').first().html());
	    templates[templateName] = t;
	} else {
	}
	this.html(t(data));
    };

    $.fn.template = function(templateName){
	return templates[templateName];
    };
    
}( jQuery ));

/****************************************************************************************************

    $(selector).fromTemplate('id', data);

Replaces HTML on selector with template merged with data

Equivalent to:

    var t = Handlebars.compile($('#' + id + '-template').html());
    $(selector).html(t(data))

but with the compiling cached upfront.

*****************************************************************************************************/
