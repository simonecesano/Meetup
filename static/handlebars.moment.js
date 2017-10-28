Handlebars.registerHelper('moment-format', function() {
    var date = arguments[0], format = arguments[1];
    date = moment(date)
    return date.format(format);
});

Handlebars.registerHelper('moment-do', function() {
    var args = Array.prototype.slice.call(arguments);

    var callback = args.shift();
    var date = moment(args.shift());
    var t = args.pop()
    
    var l = date[callback].length;
    var format = (args.length > l) ? args[l] : '';

    args = args.slice(0, date[callback].length)
    
    var r = date[callback].apply(date, args)
    return (r instanceof moment) ? r.format(format) : r;
});

