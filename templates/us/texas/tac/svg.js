
   <script type="text/javascript" id="jmo20090924">
      var iid = /.+\/(.+?)\..+$/.exec(window.location.href)[1];
      var s = document.getElementsByTagName('svg')[0];
      var bb = s.getBBox();
      s.setAttribute('viewBox', (bb.x - 10) + ' ' + (bb.y + 10) + ' ' + bb.height + ' ' + bb.width);
      s.setAttribute('height', bb.height);
      s.setAttribute('width', bb.width);
      window.parent.postMessage({ifr_height: bb.height + "px",
                                 ifr_width: bb.width + "px",
                                 ifr_id: iid}, '*');
   </script>
