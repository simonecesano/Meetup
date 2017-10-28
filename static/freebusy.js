function FreeBusy(start, freebusy, interval) {
    this.freebusy = freebusy;
    this.start    = moment(start);
    this.interval = interval;

    this.end = moment(this.start).add(this.freebusy.length * this.interval, 'minutes')

    return this;
};

FreeBusy.prototype.slot = function (time) {
    var d = moment(time).diff(this.start, 'minutes');
    return Math.floor(d / this.interval);
};

FreeBusy.prototype.slice = function (from, to) {
    var s = this.slot(from);
    var e = this.slot(to);

    return this.freebusy.substring(s, e);
};

FreeBusy.prototype.time = function(slot){
    return moment(this.start).add(slot * this.interval, 'minutes')
}

FreeBusy.prototype.slots = function(...a){
    var tentative = typeof a[a.length - 1] == 'boolean' ? a.pop() : false;
    var length = a[0] ? a[0] : 1;

    var re = tentative ?
	new RegExp(['[0-1]{', length, ',}'].join(''), 'g')
	: new RegExp(['0{', length, ',}'].join(''), 'g');

    var r = [];

    while ((match = re.exec(this.freebusy)) != null) {
	r.push([ this.time(match.index), this.time(match.index + match[0].length) ]);
    }
    return r;
};


FreeBusy.prototype.similar = function(f){
    return this.freebusy.length == f.freebusy.length && this.start.format() == f.start.format();
}

FreeBusy.prototype.overlap = function(...a) {
    var tentative = typeof a[a.length - 1] == 'boolean' ? a.pop() : false;
    var t = this;

    while (a.length) {
	if (!t.similar(a[0])) { console.log('freebusy strings are of different length or have different start'); return; }

	var o = a.shift().freebusy.split('');
	var f = t.freebusy.split('');
	var x = [];

	for (var i = 0; i < (f.length); i++) { x.push(f[i] > o[i] ? f[i] : o[i] ) }
	
	t = new FreeBusy(this.start, x.join(''))
    }
    
    return t;
}

function Schedule(start, end){
    var schedule = {};
    schedule.start    = moment(start);
    schedule.end      = moment(end);
    schedule.slot_end = moment(end);
    schedule.duration = schedule.end.diff(schedule.start, 'minutes');
    schedule.hours = [];
    schedule.minutes = [0, 15, 30, 45];

    var d = schedule.duration;
    schedule.durations = _.filter([0, 15, 30, 45, 60, 90, 120], function(e){ return e < d });
    schedule.durations.push(schedule.duration);
    
    var e = schedule.end.minute ? schedule.end : schedule.end.clone().add(1, 'hour');
    for (h = schedule.start; h < e; h = h.clone().add(1, 'hour')) { schedule.hours.push(h.hour()) }

    var set = function(obj, property, value) {
	if (property == 'start' || property == 'duration') {
	    obj[property] = value;
	    obj.end = obj.start.clone().add(obj.duration, 'minutes');
	    obj.end = obj.end > obj.slot_end ? obj.slot_end : obj.end
	}
	return obj;
    }
    
    return new Proxy(schedule, { set: set });
}
	
