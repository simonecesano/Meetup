Storage.prototype.getData = function(id){
    var d = this.getItem(id)
    if (d) { return JSON.parse(d) } else { return {} };
}

Storage.prototype.setData = function(id, data, merge){
    var s = this;
    return merge ?
	s.setItem(id, JSON.stringify(Object.assign(data, s.getData(id))))
	: s.setItem(id, JSON.stringify(data))
}

Storage.prototype.setDataFromURL = function(url, id, callback, merge){
    var s = this;
    // console.log(merge);
    if (callback && this.getItem(id)) { callback(this.getData(id)) }
    return $.get(url, function(d){
	s.setData(id, d, merge)
	if (callback) { callback(d) }
    })
};

// mergeData
// expires
