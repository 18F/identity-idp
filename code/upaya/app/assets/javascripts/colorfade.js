/*
Color Fade

Requires: jQuery 1.7.1+ (probably much lower)
Description: Simple color animation. Fades one color into another on the selected element(s)

Arguments:
- target    (object)  The target color in this format [r,g,b] defaults to white or yellow if fade_settings.flash is true
- fade_settings (object)  See code for documentation

Usage:
// Fade the background color of "#element" to rgb: 255, 253, 196
$( '#element' ).colorFade( [255, 253, 196] );
*/

(function($) {
  
  var methods = {
    
    /*
    Method to take a color input and check it and conform it to the
    format that we need
    
    Arguments:
    - color (string)  The color we are checking
    */
    conform_color : function( color ) {
      
      // If it's already array, no need to mess with it
      if ( typeof color === 'object' ) { return color; }
      
      if (  typeof color !== 'string' || !color || 'rgb(' !== color.substring( 0, 4 ) ) {
        
        return [255,255,255];
      }
      
      // Convert original color into array of number strings
      color = color.replace( /[^0-9,]/gi, '' ).split( ',' );
      
      // Parse array of number strings into array of integers
      return $.map( color, function( str ) { return parseInt( str ); });
    }
  };
  
  $.fn.colorFade = function( target, fade_settings ) {
    
    var settings = $.extend({
      
      duration  : 1000,      // (int)  How long it should take to fade the colors
      cb        : $.noop,   // (function) A callback function to be fired when fading is complete
      prop      : 'backgroundColor',  // (sring)  The CSS property whose color we are fading (defaults to backgroundColor)
      flash     : true     // (bool) Whether we are just flashing the color and we should revert to the original when we're done
      
    }, fade_settings );
    
    // Default flash color if none is provided
    if ( !target && settings.flash ) { target = [255,253,196]; }
    
    // Conform the target color to our specs
    target = methods.conform_color( target );
    
    // Return 'this' to maintain chainability
    return this.each(function() {
      
      var $this = $(this),
        original = methods.conform_color( $this.css( settings.prop ) );
      
      // Create a dummy element to animate so we can use a step function (don't insert element into DOM)
      $( '<div />' ).animate({ 'width' : 100 }, {
        
        duration  : ( settings.flash ) ? 175 : settings.duration,
        easing    : 'swing',
        
        // Fade the colors in the step function
        step : function( now, fx ) {
          
          var completion = ( now - fx.start ) / ( fx.end - fx.start );
          
          $this.css( settings.prop, 'rgb('
            + Math.round( original[0] + ( ( target[0] - original[0] ) * completion ) ) + ','
            + Math.round( original[1] + ( ( target[1] - original[1] ) * completion ) ) + ','
            + Math.round( original[2] + ( ( target[2] - original[2] ) * completion ) ) + ')'
          );
        },
        
        // Fire the callback if one was provided
        complete : function() {
          
          if ( settings.flash  ) {
            
            // Set flash to false as this will be the fade back to the original color
            settings.flash = false;
            
            // If a duration wasn't specified we set a longer default than normal
            if ( typeof fade_settings != 'object' || !( 'duration' in fade_settings ) ) {
              
              settings.duration = 2000;
            }
            
            $this.colorFade( original, settings );
            return;
          }
          
          // Call the callback
          settings.cb();
        }
      });
    });
  };
  
})(jQuery);