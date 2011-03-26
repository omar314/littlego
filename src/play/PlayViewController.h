// -----------------------------------------------------------------------------
// Copyright 2011 Patrick Näf (herzbube@herzbube.ch)
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// -----------------------------------------------------------------------------


// System includes
#import <UIKit/UIKit.h>

// Forward declarations
@class PlayView;


@interface PlayViewController : UIViewController <UIGestureRecognizerDelegate>
{
}

@property(nonatomic, retain) IBOutlet PlayView* playView;
@property(nonatomic, retain) IBOutlet UIBarButtonItem* playForMeButton;
@property(nonatomic, retain) IBOutlet UIBarButtonItem* passButton;
@property(nonatomic, retain) IBOutlet UIBarButtonItem* resignButton;
@property(nonatomic, retain) IBOutlet UIBarButtonItem* undoButton;
@property(nonatomic, retain) IBOutlet UIBarButtonItem* newGameButton;
@property(nonatomic, retain) UIPanGestureRecognizer* panRecognizer;
@property(getter=isInteractionEnabled) bool interactionEnabled;

@end