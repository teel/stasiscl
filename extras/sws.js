function toggleTableSection(secName, url) {
    // 'url' is for death reports
    // it would work with anything else but it isn't used for that
    
    var trs = document.getElementsByTagName('tr');
    for( var x = 0 ; x < trs.length ; x ++ ) {
        att = trs[x].getAttribute('name');
        if( (trs[x].className == 's' || trs[x].className == 'sectionSlave') && att == 's' + secName ) {
            if( trs[x].style.display == 'none' || (!trs[x].style.display && trs[x].className == 's') ) {
                // Making things visible.
                
                if( url && ! trs[x].cells[0].innerHTML ) {
                    var success = function(o) {
                        if( o.responseText !== undefined ) {
                            var autopsy = eval('(' + o.responseText + ')');

                            var xi = 0;
                            var trs = document.getElementsByTagName('tr');
                            for( var x = 0 ; x < trs.length ; x ++ ) {
                                att = trs[x].getAttribute('name');
                                if( att == 's' + secName ) {
                                    var tmin = Math.floor(autopsy[xi].t / 60);
                                    var tsec = Math.floor(autopsy[xi].t % 60);
                                    var tms  = Math.floor(( autopsy[xi].t - Math.floor( autopsy[xi].t ) ) * 1000);
                                    if( tms < 10 ) {
                                        tms = "00" + tms;
                                    } else if( tms < 100 ) {
                                        tms = "0" + tms;
                                    }

                                    trs[x].cells[0].innerHTML = ( tmin < 10 ? '0' + tmin.toString() : tmin.toString() ) + ":" + ( tsec < 10 ? '0' + tsec.toString() : tsec.toString() ) + "." + tms;

                                    if( autopsy[xi].hp != "0" ) {
                                        trs[x].cells[ trs[x].cells.length - 2 ].innerHTML = autopsy[xi].hp;
                                    } else {
                                        trs[x].cells[ trs[x].cells.length - 2 ].innerHTML = "";
                                    }

                                    trs[x].cells[ trs[x].cells.length - 1 ].innerHTML = autopsy[xi++].str;
                                }
                            }
                            
                            showTableSection(secName);
                        }
                    };

                    var failure = function(o) { };

                    var callback = {
                        success: success,
                        failure: failure,
                        argument: {}
                    };

                    var request = YAHOO.util.Connect.asyncRequest('GET', url, callback);
                } else {
                    showTableSection(secName);
                }
                
                return;
            } else {
                // Making things invisible.
                hideTableSection(secName);
                return;
            }
        }
    }
}

function showTableSection(secName) {
    var trs = document.getElementsByTagName('tr');
    for( var x = 0 ; x < trs.length ; x ++ ) {
        att = trs[x].getAttribute('name');
        if( (trs[x].className == 's' || trs[x].className == 'sectionSlave') && att == 's' + secName ) {
            // Making things visible.
            try {
    			trs[x].style.display = 'table-row';
    		} catch (e) {
    			// for IE
    			trs[x].style.display = 'block';
    		}
        }
    }
    
    a = document.getElementById('as'+secName);
    
    if( a ) {
        a.innerHTML = '-';
    }
}

function hideTableSection(secName) {
    var trs = document.getElementsByTagName('tr');
    for( var x = 0 ; x < trs.length ; x ++ ) {
        att = trs[x].getAttribute('name');
        if( (trs[x].className == 's' || trs[x].className == 'sectionSlave') && att == 's' + secName ) {
            trs[x].style.display = 'none';
        }
    }
    
    a = document.getElementById('as'+secName);
    
    if( a ) {
        a.innerHTML = '+';
    }
}

function toggleTab(tabId) {
    var divs = document.getElementsByTagName('div');
    for( var x = 0 ; x < divs.length ; x ++ ) {
        if( divs[x].className == 'tab' ) {
            divs[x].style.display = 'none';
        }
    }
    
    var as = document.getElementsByTagName('a');
    for( var x = 0 ; x < as.length ; x ++ ) {
        if( as[x].className == 'tabLink select' ) {
            as[x].className = 'tabLink';
        }
    }
    
    var div = document.getElementById('tab_' + tabId);
    var a = document.getElementById('tablink_' + tabId);
    div.style.display = 'block';
    a.className = 'tabLink select';
}

function hashTab() {
    var t = location.hash.substring(1);
    if( t.length > 0 ) {
        toggleTab(t)
    }
}

function initTabs() {
    var spans = document.getElementsByTagName('span');
    var tips = [];
    for( var x = 0 ; x < spans.length ; x ++ ) {
        if( spans[x].className == 'tip' ) {
            var title = spans[x].getAttribute('title');
            spans[x].setAttribute('title', '<div class="swstip">' + title.replace( /;/g, "<br />" ) + '</div>' );
            tips[tips.length] = spans[x];
        }
    }
    
    if( tips.length > 0 ) {
        var myTooltip = new YAHOO.widget.Tooltip( "swstips", { context: tips, showdelay: 0, hidedelay: 0 } );
    }
}
