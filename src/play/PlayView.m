// -----------------------------------------------------------------------------
// Copyright 2011-2013 Patrick Näf (herzbube@herzbube.ch)
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
#import "PlayView.h"
#import "PlayViewMetrics.h"
#import "PlayViewModel.h"
#import "ScoringModel.h"
#import "layer/CoordinateLabelsLayerDelegate.h"
#import "layer/CrossHairLinesLayerDelegate.h"
#import "layer/CrossHairStoneLayerDelegate.h"
#import "layer/DeadStonesLayerDelegate.h"
#import "layer/GridLayerDelegate.h"
#import "layer/StarPointsLayerDelegate.h"
#import "layer/StonesLayerDelegate.h"
#import "layer/SymbolsLayerDelegate.h"
#import "layer/TerritoryLayerDelegate.h"
#import "../main/ApplicationDelegate.h"
#import "../go/GoBoard.h"
#import "../go/GoBoardPosition.h"
#import "../go/GoGame.h"
#import "../go/GoPoint.h"
#import "../go/GoVertex.h"
#import "../utility/NSStringAdditions.h"
#import "../utility/UIColorAdditions.h"

// System includes
#import <QuartzCore/QuartzCore.h>


// -----------------------------------------------------------------------------
/// @brief Class extension with private methods for PlayView.
// -----------------------------------------------------------------------------
@interface PlayView()
/// @name Initialization and deallocation
//@{
- (id) initWithFrame:(CGRect)aRect;
- (void) dealloc;
//@}
/// @name UIView methods
//@{
- (void) layoutSubviews;
//@}
/// @name Notification responders
//@{
- (void) applicationIsReadyForAction:(NSNotification*)notification;
- (void) goGameWillCreate:(NSNotification*)notification;
- (void) goGameDidCreate:(NSNotification*)notification;
- (void) goScoreScoringModeEnabled:(NSNotification*)notification;
- (void) goScoreScoringModeDisabled:(NSNotification*)notification;
- (void) goScoreCalculationEnds:(NSNotification*)notification;
- (void) longRunningActionStarts:(NSNotification*)notification;
- (void) longRunningActionEnds:(NSNotification*)notification;
- (void) observeValueForKeyPath:(NSString*)keyPath ofObject:(id)object change:(NSDictionary*)change context:(void*)context;
//@}
/// @name Private helpers
//@{
- (void) makeViewReadyForDrawing;
- (void) setupSubLayer:(CALayer*)subLayer;
- (void) updateCrossHairPointDistanceFromFinger;
- (void) updateLayers;
- (void) delayedUpdate;
- (void) notifyLayerDelegates:(enum PlayViewLayerDelegateEvent)event eventInfo:(id)eventInfo;
//@}
/// @name Update optimizing
//@{
/// @brief Number of "expensive" actions that are currently in progress. View
/// updates are delayed while this number is >0.
@property(nonatomic, assign) int actionsInProgress;
/// @brief Is true if updates were delayed because @e actionsInProgress was >0.
@property(nonatomic, assign) bool updatesWereDelayed;
//@}
/// @name Dynamically calculated properties
//@{
@property(nonatomic, assign) float crossHairPointDistanceFromFinger;
//@}
/// @name Other privately declared properties
//@{
@property(nonatomic, assign) bool viewReadyForDrawing;
@property(nonatomic, assign) PlayViewModel* playViewModel;
@property(nonatomic, assign) ScoringModel* scoringModel;
@property(nonatomic, retain) PlayViewMetrics* playViewMetrics;
@property(nonatomic, retain) id<PlayViewLayerDelegate> gridLayerDelegate;
@property(nonatomic, retain) id<PlayViewLayerDelegate> starPointsLayerDelegate;
@property(nonatomic, retain) id<PlayViewLayerDelegate> crossHairLinesLayerDelegate;
@property(nonatomic, retain) id<PlayViewLayerDelegate> stonesLayerDelegate;
@property(nonatomic, retain) id<PlayViewLayerDelegate> crossHairStoneLayerDelegate;
@property(nonatomic, retain) id<PlayViewLayerDelegate> symbolsLayerDelegate;
@property(nonatomic, retain) id<PlayViewLayerDelegate> territoryLayerDelegate;
@property(nonatomic, retain) id<PlayViewLayerDelegate> deadStonesLayerDelegate;
@property(nonatomic, retain) id<PlayViewLayerDelegate> coordinateLabelsLetterLayerDelegate;
@property(nonatomic, retain) id<PlayViewLayerDelegate> coordinateLabelsNumberLayerDelegate;
//@}
/// @name Re-declaration of properties to make them readwrite privately
//@{
@property(nonatomic, retain, readwrite) UIScrollView* coordinateLabelsLetterViewScrollView;
@property(nonatomic, retain, readwrite) UIView* coordinateLabelsLetterView;
@property(nonatomic, retain, readwrite) UIScrollView* coordinateLabelsNumberViewScrollView;
@property(nonatomic, retain, readwrite) UIView* coordinateLabelsNumberView;
//@}
@end


@implementation PlayView

// -----------------------------------------------------------------------------
/// @brief Shared instance of PlayView.
// -----------------------------------------------------------------------------
static PlayView* sharedPlayView = nil;

// -----------------------------------------------------------------------------
/// @brief Returns the shared PlayView object.
// -----------------------------------------------------------------------------
+ (PlayView*) sharedView
{
  return sharedPlayView;
}

// -----------------------------------------------------------------------------
/// @brief Initializes a PlayView object with frame rectangle @a aRect. This
/// happens at least once during application launch, but may occur again later
/// on if the view is unloaded and then reloaded due to a memory warning.
///
/// Attempts to set up the view and make it ready for drawing. If this method
/// is invoked the very first time during application launch, the attempt fails
/// because the application delegate has not yet created all the objects that
/// are necessary for the application lifecycle. The delegate will send us a
/// notification as soon as it has finished its setup task, which will then
/// trigger the view setup.
///
/// If this method is invoked again later during the application's lifetime,
/// the setup attempt will succeed because all the necessary objects are already
/// there.
///
/// @note This is the designated initializer of PlayView.
// -----------------------------------------------------------------------------
- (id) initWithFrame:(CGRect)aRect
{
  // Call designated initializer of superclass (NSView)
  self = [super initWithFrame:aRect];
  if (! self)
    return nil;

  sharedPlayView = self;

  ApplicationDelegate* delegate = [ApplicationDelegate sharedDelegate];
  self.playViewModel = delegate.playViewModel;
  self.scoringModel = delegate.scoringModel;
  // Cannot delay creation of the metrics object to makeViewReadyForDrawing()
  // because external forces need access to the boardFrame property
  self.playViewMetrics = [[[PlayViewMetrics alloc] initWithView:self
                                                          model:self.playViewModel] autorelease];

  if (! delegate.applicationReadyForAction)
  {
    self.viewReadyForDrawing = false;
    NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(applicationIsReadyForAction:) name:applicationIsReadyForAction object:nil];
  }
  else
  {
    [self makeViewReadyForDrawing];
    self.viewReadyForDrawing = true;
  }

  return self;
}

// -----------------------------------------------------------------------------
/// @brief Deallocates memory allocated by this PlayView object.
// -----------------------------------------------------------------------------
- (void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [self.playViewModel removeObserver:self forKeyPath:@"markLastMove"];
  [self.playViewModel removeObserver:self forKeyPath:@"displayCoordinates"];
  [self.playViewModel removeObserver:self forKeyPath:@"moveNumbersPercentage"];
  [self.playViewModel removeObserver:self forKeyPath:@"stoneDistanceFromFingertip"];
  [self.scoringModel removeObserver:self forKeyPath:@"inconsistentTerritoryMarkupType"];
  [[GoGame sharedGame].boardPosition removeObserver:self forKeyPath:@"currentBoardPosition"];

  self.playViewModel = nil;
  self.scoringModel = nil;
  self.crossHairPoint = nil;
  if (self == sharedPlayView)
    sharedPlayView = nil;

  self.playViewMetrics = nil;
  self.gridLayerDelegate = nil;
  self.starPointsLayerDelegate = nil;
  self.crossHairLinesLayerDelegate = nil;
  self.stonesLayerDelegate = nil;
  self.crossHairStoneLayerDelegate = nil;
  self.symbolsLayerDelegate = nil;
  self.territoryLayerDelegate = nil;
  self.deadStonesLayerDelegate = nil;
  self.coordinateLabelsLetterLayerDelegate = nil;
  self.coordinateLabelsNumberLayerDelegate = nil;

  self.coordinateLabelsLetterViewScrollView = nil;
  self.coordinateLabelsLetterView = nil;
  self.coordinateLabelsNumberViewScrollView = nil;
  self.coordinateLabelsNumberView = nil;

  [super dealloc];
}

// -----------------------------------------------------------------------------
/// @brief Responds to the #applicationIsReadyForAction notification.
// -----------------------------------------------------------------------------
- (void) applicationIsReadyForAction:(NSNotification*)notification
{
  // We only need this notification once
  [[NSNotificationCenter defaultCenter] removeObserver:self name:applicationIsReadyForAction object:nil];

  [self makeViewReadyForDrawing];
  self.viewReadyForDrawing = true;

  // Now perform all drawing updates that have accumulated so far
  // (at least layoutSubviews(), which has been invoked at least once after
  // initialization)
  [self delayedUpdate];
}

// -----------------------------------------------------------------------------
/// @brief Sets up the view and makes it ready for drawing.
// -----------------------------------------------------------------------------
- (void) makeViewReadyForDrawing
{
  self.crossHairPoint = nil;
  self.crossHairPointIsLegalMove = true;
  self.crossHairPointDistanceFromFinger = 0;

  self.actionsInProgress = 0;
  self.updatesWereDelayed = false;

  NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
  [center addObserver:self selector:@selector(goGameWillCreate:) name:goGameWillCreate object:nil];
  [center addObserver:self selector:@selector(goGameDidCreate:) name:goGameDidCreate object:nil];
  [center addObserver:self selector:@selector(goScoreScoringModeEnabled:) name:goScoreScoringModeEnabled object:nil];
  [center addObserver:self selector:@selector(goScoreScoringModeDisabled:) name:goScoreScoringModeDisabled object:nil];
  [center addObserver:self selector:@selector(goScoreCalculationEnds:) name:goScoreCalculationEnds object:nil];
  [center addObserver:self selector:@selector(longRunningActionStarts:) name:longRunningActionStarts object:nil];
  [center addObserver:self selector:@selector(longRunningActionEnds:) name:longRunningActionEnds object:nil];
  // KVO observing
  [self.playViewModel addObserver:self forKeyPath:@"markLastMove" options:0 context:NULL];
  [self.playViewModel addObserver:self forKeyPath:@"displayCoordinates" options:0 context:NULL];
  [self.playViewModel addObserver:self forKeyPath:@"moveNumbersPercentage" options:0 context:NULL];
  [self.playViewModel addObserver:self forKeyPath:@"stoneDistanceFromFingertip" options:0 context:NULL];
  [self.scoringModel addObserver:self forKeyPath:@"inconsistentTerritoryMarkupType" options:0 context:NULL];
  GoGame* game = [GoGame sharedGame];
  if (game)
    [game.boardPosition addObserver:self forKeyPath:@"currentBoardPosition" options:0 context:NULL];

  // One-time initialization
  [self updateCrossHairPointDistanceFromFinger];

  // If we already have a game, recalculate
  if (game)
    [self.playViewMetrics updateWithBoardSize:game.board.size];


  self.gridLayerDelegate = [[[GridLayerDelegate alloc] initWithLayer:[CALayer layer]
                                                             metrics:self.playViewMetrics
                                                               model:self.playViewModel] autorelease];
  self.starPointsLayerDelegate = [[[StarPointsLayerDelegate alloc] initWithLayer:[CALayer layer]
                                                                         metrics:self.playViewMetrics
                                                                           model:self.playViewModel] autorelease];
  self.crossHairLinesLayerDelegate = [[[CrossHairLinesLayerDelegate alloc] initWithLayer:[CALayer layer]
                                                                                 metrics:self.playViewMetrics
                                                                                   model:self.playViewModel] autorelease];
  self.stonesLayerDelegate = [[[StonesLayerDelegate alloc] initWithLayer:[CALayer layer]
                                                                 metrics:self.playViewMetrics
                                                                   model:self.playViewModel] autorelease];
  self.crossHairStoneLayerDelegate = [[[CrossHairStoneLayerDelegate alloc] initWithLayer:[CALayer layer]
                                                                                 metrics:self.playViewMetrics
                                                                                   model:self.playViewModel] autorelease];
  self.symbolsLayerDelegate = [[[SymbolsLayerDelegate alloc] initWithLayer:[CALayer layer]
                                                                   metrics:self.playViewMetrics
                                                             playViewModel:self.playViewModel
                                                              scoringModel:self.scoringModel] autorelease];
  self.territoryLayerDelegate = [[[TerritoryLayerDelegate alloc] initWithLayer:[CALayer layer]
                                                                       metrics:self.playViewMetrics
                                                                 playViewModel:self.playViewModel
                                                                  scoringModel:self.scoringModel] autorelease];
  self.deadStonesLayerDelegate = [[[DeadStonesLayerDelegate alloc] initWithLayer:[CALayer layer]
                                                                         metrics:self.playViewMetrics
                                                                   playViewModel:self.playViewModel
                                                                    scoringModel:self.scoringModel] autorelease];

  // TODO xxx no longer need a method for the setup
  // TODO xxx in fact: why can't the layer delegate create its own layer? we
  // just pass it the main view, and it adds the layer as a sublayer...
  [self setupSubLayer:_gridLayerDelegate.layer];
  [self setupSubLayer:_starPointsLayerDelegate.layer];
  [self setupSubLayer:_crossHairLinesLayerDelegate.layer];
  [self setupSubLayer:_stonesLayerDelegate.layer];
  [self setupSubLayer:_crossHairStoneLayerDelegate.layer];
  [self setupSubLayer:_symbolsLayerDelegate.layer];
  [self setupSubLayer:_territoryLayerDelegate.layer];
  [self setupSubLayer:_deadStonesLayerDelegate.layer];

  self.coordinateLabelsLetterViewScrollView = [[[UIScrollView alloc] initWithFrame:CGRectZero] autorelease];
  self.coordinateLabelsLetterViewScrollView.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);
  self.coordinateLabelsLetterViewScrollView.backgroundColor = [UIColor clearColor];
  self.coordinateLabelsLetterViewScrollView.userInteractionEnabled = NO;
  self.coordinateLabelsLetterView = [[[UIView alloc] initWithFrame:CGRectZero] autorelease];
  [self.coordinateLabelsLetterViewScrollView addSubview:self.coordinateLabelsLetterView];
  self.coordinateLabelsLetterLayerDelegate = [[[CoordinateLabelsLayerDelegate alloc] initWithLayer:[CALayer layer]
                                                                                           metrics:self.playViewMetrics
                                                                                             model:self.playViewModel
                                                                                              axis:CoordinateLabelAxisLetter
                                                                                              view:self.coordinateLabelsLetterView] autorelease];
  [self.coordinateLabelsLetterView.layer addSublayer:_coordinateLabelsLetterLayerDelegate.layer];

  self.coordinateLabelsNumberViewScrollView = [[[UIScrollView alloc] initWithFrame:CGRectZero] autorelease];
  self.coordinateLabelsNumberViewScrollView.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);
  self.coordinateLabelsNumberViewScrollView.backgroundColor = [UIColor clearColor];
  self.coordinateLabelsNumberViewScrollView.userInteractionEnabled = NO;
  self.coordinateLabelsNumberView = [[[UIView alloc] initWithFrame:CGRectZero] autorelease];
  [self.coordinateLabelsNumberViewScrollView addSubview:self.coordinateLabelsNumberView];
  self.coordinateLabelsNumberLayerDelegate = [[[CoordinateLabelsLayerDelegate alloc] initWithLayer:[CALayer layer]
                                                                                           metrics:self.playViewMetrics
                                                                                             model:self.playViewModel
                                                                                              axis:CoordinateLabelAxisNumber
                                                                                              view:self.coordinateLabelsNumberView] autorelease];
  [self.coordinateLabelsNumberView.layer addSublayer:_coordinateLabelsNumberLayerDelegate.layer];
}

// -----------------------------------------------------------------------------
/// @brief Sets up the specified layer as a sublayer of this Play view.
// -----------------------------------------------------------------------------
- (void) setupSubLayer:(CALayer*)subLayer
{
  [self.layer addSublayer:subLayer];
}

// -----------------------------------------------------------------------------
/// @brief Internal helper that correctly handles delayed updates. PlayView
/// methods that need a view update should invoke this helper instead of
/// updateLayers().
///
/// If @e actionsInProgress is 0, this helper invokes updateLayers(),
/// thus triggering the update in UIKit.
///
/// If @e actionsInProgress is >0, this helper sets @e updatesWereDelayed to
/// true.
// -----------------------------------------------------------------------------
- (void) delayedUpdate
{
  if (self.actionsInProgress > 0)
    self.updatesWereDelayed = true;
  else
    [self updateLayers];
}

// -----------------------------------------------------------------------------
/// @brief Notifies all layers that they need to update now if they are dirty.
/// This marks one update cycle.
// -----------------------------------------------------------------------------
- (void) updateLayers
{
  // Guard against
  // - updates triggered while the view is still uninitialized and not yet ready
  //   for drawing (occurs during application launch)
  if (! self.viewReadyForDrawing)
  {
    self.updatesWereDelayed = true;
    return;
  }
  // No game -> no board -> no drawing. This situation exists right after the
  // application has launched and the initial game is created only after a
  // small delay.
  if (! [GoGame sharedGame])
    return;
  self.updatesWereDelayed = false;

  [_gridLayerDelegate drawLayer];
  [_starPointsLayerDelegate drawLayer];
  [_crossHairLinesLayerDelegate drawLayer];
  [_stonesLayerDelegate drawLayer];
  [_crossHairStoneLayerDelegate drawLayer];
  [_symbolsLayerDelegate drawLayer];
  [_territoryLayerDelegate drawLayer];
  [_deadStonesLayerDelegate drawLayer];
  [_coordinateLabelsLetterLayerDelegate drawLayer];
  [_coordinateLabelsNumberLayerDelegate drawLayer];
}

// -----------------------------------------------------------------------------
/// @brief Notifies all layer delegates that @a event has occurred. The event
/// info object supplied to the delegates is @a eventInfo.
///
/// Delegates will ignore the event, or react to the event, as appropriate for
/// the layer that they manage.
// -----------------------------------------------------------------------------
- (void) notifyLayerDelegates:(enum PlayViewLayerDelegateEvent)event eventInfo:(id)eventInfo
{
  [_gridLayerDelegate notify:event eventInfo:eventInfo];
  [_starPointsLayerDelegate notify:event eventInfo:eventInfo];
  [_crossHairLinesLayerDelegate notify:event eventInfo:eventInfo];
  [_stonesLayerDelegate notify:event eventInfo:eventInfo];
  [_crossHairStoneLayerDelegate notify:event eventInfo:eventInfo];
  [_symbolsLayerDelegate notify:event eventInfo:eventInfo];
  [_territoryLayerDelegate notify:event eventInfo:eventInfo];
  [_deadStonesLayerDelegate notify:event eventInfo:eventInfo];
  [_coordinateLabelsLetterLayerDelegate notify:event eventInfo:eventInfo];
  [_coordinateLabelsNumberLayerDelegate notify:event eventInfo:eventInfo];
}

// -----------------------------------------------------------------------------
/// @brief UIView method.
///
/// Overriding this method is important so that we can react to frame size
/// changes that occur when this view is autoresized, e.g. when the device
/// orientation changes.
///
/// This is also invoked soon after initialization.
// -----------------------------------------------------------------------------
- (void) layoutSubviews
{
  [super layoutSubviews];

  // Disabling animations here is essential for a smooth GUI update after a zoom
  // operation ends. If animations were enabled, setting the layer frames would
  // trigger an animation that looks like a "bounce". For details see
  // http://stackoverflow.com/questions/15370803/how-to-prevent-bounce-effect-when-a-custom-view-redraws-after-zooming
  [CATransaction begin];
  [CATransaction setDisableActions:YES];
  [self.playViewMetrics updateWithRect:self.bounds];
  [self layoutCoordinateLabelView:self.coordinateLabelsLetterView
                       scrollView:self.coordinateLabelsLetterViewScrollView];
  [self layoutCoordinateLabelView:self.coordinateLabelsNumberView
                       scrollView:self.coordinateLabelsNumberViewScrollView];
  [self notifyLayerDelegates:PVLDEventRectangleChanged eventInfo:nil];
  [self delayedUpdate];
  [CATransaction commit];
}

// -----------------------------------------------------------------------------
/// @brief Private helper for layoutSubviews.
// -----------------------------------------------------------------------------
- (void) layoutCoordinateLabelView:(UIView*)view scrollView:(UIScrollView*)scrollView
{
  CGRect viewFrame = view.frame;
  CGRect scrollViewFrame = scrollView.frame;
  if (view == self.coordinateLabelsLetterView)
  {
    viewFrame.size.width = self.bounds.size.width;
    viewFrame.size.height = self.playViewMetrics.coordinateLabelStripWidth;
    scrollViewFrame.size.width = self.superview.bounds.size.width;
    scrollViewFrame.size.height = self.playViewMetrics.coordinateLabelStripWidth;
  }
  else
  {
    viewFrame.size.width = self.playViewMetrics.coordinateLabelStripWidth;
    viewFrame.size.height = self.bounds.size.height;
    scrollViewFrame.size.width = self.playViewMetrics.coordinateLabelStripWidth;
    scrollViewFrame.size.height = self.superview.bounds.size.height;
  }
  view.frame = viewFrame;
  scrollView.contentSize = viewFrame.size;
  // Changing the scroll view frame resets the content offset to (0,0). This
  // must not happen because it would position the coordinate labels wrongly
  // after a zoom operation. We preserve the content offset by re-applying it
  // after the frame change.
  CGPoint contentOffset = scrollView.contentOffset;
  scrollView.frame = scrollViewFrame;
  scrollView.contentOffset = contentOffset;
}

// -----------------------------------------------------------------------------
/// @brief Responds to the #goGameWillCreate notification.
// -----------------------------------------------------------------------------
- (void) goGameWillCreate:(NSNotification*)notification
{
  GoGame* oldGame = [notification object];
  [oldGame.boardPosition removeObserver:self forKeyPath:@"currentBoardPosition"];
}

// -----------------------------------------------------------------------------
/// @brief Responds to the #goGameDidCreate notification.
// -----------------------------------------------------------------------------
- (void) goGameDidCreate:(NSNotification*)notification
{
  GoGame* newGame = [notification object];
  [newGame.boardPosition addObserver:self forKeyPath:@"currentBoardPosition" options:0 context:NULL];
  [self updateCrossHairPointDistanceFromFinger];  // depends on board size
  [self.playViewMetrics updateWithBoardSize:[GoGame sharedGame].board.size];
  [self notifyLayerDelegates:PVLDEventGoGameStarted eventInfo:nil];
  [self delayedUpdate];
}

// -----------------------------------------------------------------------------
/// @brief Responds to the #goScoreScoringModeEnabled notification.
// -----------------------------------------------------------------------------
- (void) goScoreScoringModeEnabled:(NSNotification*)notification
{
  [self notifyLayerDelegates:PVLDEventScoringModeEnabled eventInfo:nil];
  [self delayedUpdate];
}

// -----------------------------------------------------------------------------
/// @brief Responds to the #goScoreScoringModeDisabled notification.
// -----------------------------------------------------------------------------
- (void) goScoreScoringModeDisabled:(NSNotification*)notification
{
  [self notifyLayerDelegates:PVLDEventScoringModeDisabled eventInfo:nil];
  [self delayedUpdate];
}

// -----------------------------------------------------------------------------
/// @brief Responds to the #goScoreCalculationEnds notifications.
// -----------------------------------------------------------------------------
- (void) goScoreCalculationEnds:(NSNotification*)notification
{
  [self notifyLayerDelegates:PVLDEventScoreCalculationEnds eventInfo:nil];
  [self delayedUpdate];
}

// -----------------------------------------------------------------------------
/// @brief Responds to the #longRunningActionStarts notifications.
///
/// Increases @e actionsInProgress by 1.
// -----------------------------------------------------------------------------
- (void) longRunningActionStarts:(NSNotification*)notification
{
  self.actionsInProgress++;
  DDLogVerbose(@"PlayView, longRunningActionStarts, new value for self.actionsInProgress = %d", self.actionsInProgress);
}

// -----------------------------------------------------------------------------
/// @brief Responds to the #longRunningActionEnds notifications.
///
/// Decreases @e actionsInProgress by 1. Triggers a view update if
/// @e actionsInProgress becomes 0 and @e updatesWereDelayed is true.
// -----------------------------------------------------------------------------
- (void) longRunningActionEnds:(NSNotification*)notification
{
  self.actionsInProgress--;
  if (0 == self.actionsInProgress)
  {
    if (self.updatesWereDelayed)
      [self updateLayers];
  }
  DDLogVerbose(@"PlayView, longRunningActionEnds, new value for self.actionsInProgress = %d", self.actionsInProgress);
}

// -----------------------------------------------------------------------------
/// @brief Responds to KVO notifications.
// -----------------------------------------------------------------------------
- (void) observeValueForKeyPath:(NSString*)keyPath ofObject:(id)object change:(NSDictionary*)change context:(void*)context
{
  if (object == self.scoringModel)
  {
    if ([keyPath isEqualToString:@"inconsistentTerritoryMarkupType"])
    {
      if (self.scoringModel.scoringMode)
      {
        [self notifyLayerDelegates:PVLDEventInconsistentTerritoryMarkupTypeChanged eventInfo:nil];
        [self delayedUpdate];
      }
    }
  }
  else if (object == self.playViewModel)
  {
    if ([keyPath isEqualToString:@"markLastMove"])
    {
      [self notifyLayerDelegates:PVLDEventMarkLastMoveChanged eventInfo:nil];
      [self delayedUpdate];
    }
    else if ([keyPath isEqualToString:@"displayCoordinates"])
    {
      [self notifyLayerDelegates:PVLDEventDisplayCoordinatesChanged eventInfo:nil];
      [self setNeedsLayout];
    }
    else if ([keyPath isEqualToString:@"moveNumbersPercentage"])
    {
      [self notifyLayerDelegates:PVLDEventMoveNumbersPercentageChanged eventInfo:nil];
      [self delayedUpdate];
    }
    else if ([keyPath isEqualToString:@"stoneDistanceFromFingertip"])
      [self updateCrossHairPointDistanceFromFinger];
  }
  else if (object == [GoGame sharedGame].boardPosition)
  {
    [self notifyLayerDelegates:PVLDEventBoardPositionChanged eventInfo:nil];
    [self delayedUpdate];
  }
}

// -----------------------------------------------------------------------------
/// @brief Updates self.crossHairPointDistanceFromFinger.
///
/// The calculation performed by this method depends on the following input
/// parameters:
/// - The value of the "stone distance from fingertip" user preference
/// - The current board size
// -----------------------------------------------------------------------------
- (void) updateCrossHairPointDistanceFromFinger
{
  GoGame* game = [GoGame sharedGame];
  float scaleFactor;
  if (! game)
    scaleFactor = 1.0;
  else
  {
    // Distance from fingertip should scale with board size. The base for
    // calculating the scale factor is the minimum board size.
    scaleFactor = 1.0 * game.board.size / GoBoardSizeMin;
    // Straight scaling results in a scale factor that is too large for big
    // boards, so we tune down the scale a little bit. The following
    // hard-coded factor has been determined experimentally.
    scaleFactor *= 0.6;
    // The final scale factor must not drop below 1 because we don't want to
    // get below stoneDistanceFromFingertip.
    if (scaleFactor < 1.0)
      scaleFactor = 1.0;
  }
  self.crossHairPointDistanceFromFinger = self.playViewModel.stoneDistanceFromFingertip * scaleFactor;
}

// -----------------------------------------------------------------------------
/// @brief Returns a GoPoint object for the intersection that is closest to the
/// view coordinates @a coordinates. Returns nil if there is no "closest"
/// intersection.
///
/// Determining "closest" works like this:
/// - If the user has turned this on in the preferences, @a coordinates are
///   slightly adjusted so that the intersection is not directly under the
///   user's fingertip
/// - Otherwise the same rules as for pointNear:() apply - see that method's
///   documentation.
// -----------------------------------------------------------------------------
- (GoPoint*) crossHairPointNear:(CGPoint)coordinates
{
  // Adjust so that the cross-hair is not directly under the user's fingertip,
  // but one or more point distances above
  coordinates.y -= self.crossHairPointDistanceFromFinger * self.playViewMetrics.pointDistance;
  return [_playViewMetrics pointNear:coordinates];
}

// -----------------------------------------------------------------------------
/// @brief Moves the cross-hair to the intersection identified by @a point,
/// specifying whether an actual play move at the intersection would be legal.
// -----------------------------------------------------------------------------
- (void) moveCrossHairTo:(GoPoint*)point isLegalMove:(bool)isLegalMove
{
  if (_crossHairPoint == point && _crossHairPointIsLegalMove == isLegalMove)
    return;

  // Update *BEFORE* self.crossHairPoint so that KVO observers that monitor
  // self.crossHairPoint get both changes at once. Don't use self to update the
  // property because we don't want observers to monitor the property via KVO.
  _crossHairPointIsLegalMove = isLegalMove;
  self.crossHairPoint = point;

  [self notifyLayerDelegates:PVLDEventCrossHairChanged eventInfo:point];
  [self delayedUpdate];
}

// -----------------------------------------------------------------------------
/// @brief Returns a GoPoint object for the intersection that is closest to the
/// view coordinates @a coordinates. Returns nil if there is no "closest"
/// intersection.
///
/// @see PlayViewMetrics::pointNear:() for details.
// -----------------------------------------------------------------------------
- (GoPoint*) pointNear:(CGPoint)coordinates
{
  return [_playViewMetrics pointNear:coordinates];
}

// -----------------------------------------------------------------------------
// Property is documented in the header file.
// -----------------------------------------------------------------------------
- (CGRect) boardFrame
{
  return CGRectMake(self.frame.origin.x + _playViewMetrics.topLeftBoardCornerX,
                    self.frame.origin.y + _playViewMetrics.topLeftBoardCornerY,
                    _playViewMetrics.boardSideLength,
                    _playViewMetrics.boardSideLength);
}

@end
