# TORevealViewController
#### A UISplitViewController style implementation that displays a standard view controller by default, but an additional, smaller view controller can be slid out over the standard controller from the left hand-side.

![TORevealViewController on iPad](https://raw.github.com/TimOliver/TORevealViewController/master/Screenshots/TORevealViewController.png)

## What is this thing?

TORevealViewController is my own implementation of a UISplitViewController style view controller that works on both iPhone and iPad, where a 
'detail view controller' (which takes up the whole screen) is displayed by default, but a smaller 'master view controller' can be toggled into
view at any point.
I decided to implement this myself over using UISplitViewController as this one lets me configure it for both iPhone and iPad at the same time, and 
also implements a nicer set of animated gestures.

TORevealViewController supports iOS 5 and above.

## Features

  * Upon toggle, the master view controller slides in over the top of the detail controller in a fluid, iOS 7 style
  * Aside from tapping the 'menu' button, the master view controller can also be shown by sliding your finger horizintally along the screen.
  * The size of the master view controller can be configured, in case the full height of the display isn't necessary.

## License

TORevealViewController is licensed under the MIT License. While attribution would be appreciated, it is not required.

- - -

Copyright 2013 Timothy Oliver. All rights reserved.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to
deal in the Software without restriction, including without limitation the
rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
sell copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR
IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.