// Thanks http://beski.wordpress.com/2009/04/21/scroll-effect-with-local-anchors-jquery/

function scroll_to_anchor(anchor) {
	var full_url = this.href;

	//get the top offset of the target anchor
	var target_offset = $("#"+anchor).offset();
	var target_top = target_offset.top;

	//goto that anchor by setting the body scroll top to anchor top
	$('html, body').animate({scrollTop:target_top}, 500);
};



function show_fonts(list_id) {
  $('#show_fonts').empty();
  
  $('#show_fonts').append("<p class=\"drag-drop-message\">You can drag and drop each block to compare them more closely</p>");
  
  $('#' + list_id + ' li').each(function() {
      var font_name = $(this).text();
      var html_result = '';
      
      html_result += '<div class="font draggable" style="font-family: ' + font_name + '">'
      html_result += '<p style="font-size:4em">' + font_name + '</p>'
      html_result += '<p style="font-size:2em">' + font_name + '</p>'
      html_result += '<p style="font-size:1.5em">' + font_name + '</p>'
      html_result += '<p style="font-size:1em">' + font_name + '</p>'
      html_result += '</div>'

      $('#show_fonts').append(html_result);      
      
      $(".draggable").draggable();
  });
}


$(function() {
  
  $('ul').click(function() {
    show_fonts($(this).attr('id'));
    scroll_to_anchor('show_fonts');
  });
  
  $('.bottom a').click(function(e) {
    e.preventDefault();
    scroll_to_anchor('top');
  });
  
});