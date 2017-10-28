(function ( $ ) {
    var templates = {};

    $(function(){
	$(window.document.body).find("[type='text/x-handlebars-template']").each(function(){
	    var id = $(this).attr('id').replace(/\W*template/i, '').replace(/\W+/, '_')
	    templates[id] = Handlebars.compile($(this).html());
	    console.log($(this).html())
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
