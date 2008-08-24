function toggleTableSection(secName) {
    var number = 0;
    var text = '?';
    
    var trs = document.getElementsByTagName('tr');
    for( var x = 0 ; x < trs.length ; x ++ ) {
        att = trs[x].getAttribute('name');
        if( att == 'section_' + secName || att == 's' + secName ) {
            trs[x].style.display = trs[x].style.display == 'none' ? '' : 'none';
            text = trs[x].style.display == 'none' ? '+' : '-';
            number ++;
        }
    }
    
    if( number > 0 ) {
        a1 = document.getElementById('a_section_'+secName);
        a2 = document.getElementById('as'+secName);
        
        if( a1 ) {
            a1.innerHTML = text;
        }
        
        if( a2 ) {
            a2.innerHTML = text;
        }
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
