// -----------------------------------------------------------------------------
// Copyright 2013 Patrick Näf (herzbube@herzbube.ch)
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


// Project includes
#import "BoardPositionView.h"
#import "BoardPositionViewMetrics.h"
#import "../../go/GoGame.h"
#import "../../go/GoMove.h"
#import "../../go/GoMoveModel.h"
#import "../../go/GoPlayer.h"
#import "../../go/GoPoint.h"
#import "../../go/GoVertex.h"
#import "../../utility/UIColorAdditions.h"

// System includes
#import <QuartzCore/QuartzCore.h>


// -----------------------------------------------------------------------------
/// @brief Class extension with private methods for BoardPositionView.
// -----------------------------------------------------------------------------
@interface BoardPositionView()
/// @name Initialization and deallocation
//@{
- (void) dealloc;
//@}
/// @name Overrides from superclass
//@{
- (void) layoutSubviews;
//@}
/// @name Private helpers
//@{
- (NSString*) labelTextForMove:(GoMove*)move moveIndex:(int)moveIndex;
- (UILabel*) labelWithText:(NSString*)labelText;
- (UIImageView*) stoneImageViewForMove:(GoMove*)move;
- (void) setupBackgroundColorForMove:(GoMove*)move;
//@}
/// @name Privately declared properties
//@{
@property(nonatomic, assign) BoardPositionViewMetrics* viewMetrics;
//@}
@end


@implementation BoardPositionView

@synthesize boardPosition;
@synthesize currentBoardPosition;
@synthesize viewMetrics;


// -----------------------------------------------------------------------------
/// @brief Initializes a BoardPositionView object that represents the board
/// position identified by @a aBoardPosition and uses @a aViewMetrics to obtain
/// sizes and other attributes that define the view's layout.
///
/// @note This is the designated initializer of BoardPositionView.
// -----------------------------------------------------------------------------
- (id) initWithBoardPosition:(int)aBoardPosition viewMetrics:(BoardPositionViewMetrics*)aViewMetrics
{
  // Call designated initializer of superclass (UIView)
  self = [super initWithFrame:CGRectMake(0, 0, 0, 0)];
  if (! self)
    return nil;

  self.boardPosition = aBoardPosition;
  self.currentBoardPosition = false;
  self.viewMetrics = aViewMetrics;

  self.frame = self.viewMetrics.boardPositionViewFrame;

  return self;
}

// -----------------------------------------------------------------------------
/// @brief Deallocates memory allocated by this BoardPositionView
/// object.
// -----------------------------------------------------------------------------
- (void) dealloc
{
  self.viewMetrics = nil;
  [super dealloc];
}

// -----------------------------------------------------------------------------
/// @brief This overrides the superclass implementation.
// -----------------------------------------------------------------------------
- (void) layoutSubviews
{
  [super layoutSubviews];

  GoMove* move = nil;
  if (0 == self.boardPosition)
  {
    // TODO xxx do stuff for board position 0
  }
  else
  {
    int moveIndex = self.boardPosition - 1;
    move = [[GoGame sharedGame].moveModel moveAtIndex:moveIndex];
    NSString* labelText = [self labelTextForMove:move moveIndex:moveIndex];
    UILabel* label = [self labelWithText:labelText];
    UIImageView* stoneImageView = [self stoneImageViewForMove:move];
    [self addSubview:label];
    [self addSubview:stoneImageView];
  }

  [self setupBackgroundColorForMove:move];
}

// -----------------------------------------------------------------------------
/// @brief This is an internal helper for layoutSubviews().
// -----------------------------------------------------------------------------
- (NSString*) labelTextForMove:(GoMove*)move moveIndex:(int)moveIndex
{
  NSString* vertexString;
  if (GoMoveTypePlay == move.type)
    vertexString = move.point.vertex.string;
  else
    vertexString = @"Pass";
  int moveNumber = moveIndex + 1;
  return [NSString stringWithFormat:@"%d\n%@", moveNumber, vertexString];
}

// -----------------------------------------------------------------------------
/// @brief This is an internal helper for layoutSubviews().
// -----------------------------------------------------------------------------
- (UILabel*) labelWithText:(NSString*)labelText
{
  UILabel* label = [[[UILabel alloc] initWithFrame:self.viewMetrics.labelFrame] autorelease];
  label.font = [UIFont systemFontOfSize:[BoardPositionViewMetrics boardPositionViewFontSize]];
  [label setNumberOfLines:self.viewMetrics.labelNumberOfLines];
  label.backgroundColor = [UIColor clearColor];
  label.text = labelText;
  return label;
}

// -----------------------------------------------------------------------------
/// @brief This is an internal helper for layoutSubviews().
// -----------------------------------------------------------------------------
- (UIImageView*) stoneImageViewForMove:(GoMove*)move
{
  UIImage* stoneImage;
  if (move.player.black)
    stoneImage = self.viewMetrics.blackStoneImage;
  else
    stoneImage = self.viewMetrics.whiteStoneImage;
  UIImageView* stoneImageView = [[[UIImageView alloc] initWithImage:stoneImage] autorelease];
  stoneImageView.frame = self.viewMetrics.stoneImageViewFrame;
  return stoneImageView;
}

// -----------------------------------------------------------------------------
/// @brief This is an internal helper for layoutSubviews().
// -----------------------------------------------------------------------------
- (void) setupBackgroundColorForMove:(GoMove*)move
{
  if (self.currentBoardPosition)
  {
    self.backgroundColor = [UIColor colorWithRed:0.0f
                                           green:0.667f
                                            blue:1.0f
                                           alpha:1.0f];
  }
  else if (0 == self.boardPosition)
  {
    if (0 == [GoGame sharedGame].handicapPoints.count)
      self.backgroundColor = [UIColor lightGrayColor];
    else
      self.backgroundColor = [UIColor whiteColor];
  }
  else
  {
    if (move.player.black)
      self.backgroundColor = [UIColor whiteColor];
    else
      self.backgroundColor = [UIColor lightGrayColor];
  }
}

// -----------------------------------------------------------------------------
// Property is documented in the header file.
// -----------------------------------------------------------------------------
- (void) setCurrentBoardPosition:(bool)newValue
{
  if (currentBoardPosition == newValue)
    return;
  currentBoardPosition = newValue;
  [self setNeedsLayout];
}

@end
