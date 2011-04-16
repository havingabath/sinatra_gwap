 


function startTime(chain_start)
{
	var now = Math.round(new Date().getTime()/1000.0)
	var sec = (now - parseInt(chain_start));
	var hr = Math.floor(sec / 3600);
	var min = Math.floor((sec - (hr * 3600))/60);
	sec -= ((hr * 3600) + (min * 60));


// add a zero in front of numbers<10

min=checkTime(min);
sec=checkTime(sec);
hr = (hr)?hr+':':'';

document.getElementById('time').innerHTML=hr+min+":"+sec;
//t=setTimeout('startTime(chain_start)',500);
t=setTimeout(function(){startTime(chain_start)},500);
}

function checkTime(i)
{
if (i<10)
  {
  i="0" + i;
  }
return i;
}

function secondsToTime(secs)
{
    var hours = Math.floor(secs / (60 * 60));
   
    var divisor_for_minutes = secs % (60 * 60);
    var minutes = Math.floor(divisor_for_minutes / 60);
 
    var divisor_for_seconds = divisor_for_minutes % 60;
    var seconds = Math.ceil(divisor_for_seconds);
   
    var obj = {
        "h": hours,
        "m": minutes,
        "s": seconds
    };
    return obj;
}