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
