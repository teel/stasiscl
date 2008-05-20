function toggleTableSection(secName) {
    var number = 0;
    var text = '?';
    
    var trs = document.getElementsByTagName('tr');
    for( var x = 0 ; x < trs.length ; x ++ ) {
        att = trs[x].getAttribute('name');
        if( att == 'section_' + secName ) {
            trs[x].style.display = trs[x].style.display == 'none' ? '' : 'none';
            text = trs[x].style.display == 'none' ? '+' : '-';
            number ++;
        }
    }
    
    if( number > 0 ) {
        document.getElementById('a_section_'+secName).innerHTML = text;
    }
}

function toggleActorGroup(grpName) {
    
}
