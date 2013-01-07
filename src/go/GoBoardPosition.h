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


// Forward declarations
@class GoGame;
@class GoMove;
@class GoPlayer;


// -----------------------------------------------------------------------------
/// @brief The GoBoardPosition class defines which position of the Go board is
/// currently described by the GoPoint and GoBoardRegion objects attached to a
/// given GoGame.
///
/// A board position is how the Go board looks like after a move has been made
/// by a player. Although the Go board does not look differently after a pass
/// move has been made, the board before and after the move is considered to be
/// in a different position.
///
/// In the course of a game, a new board position is created by each move made
/// by a player. GoBoardPosition provides a simple way how to refer to a board
/// position: The reference is made with a numeric value:
/// - Board position 0 refers to the beginning of the game, i.e. when no moves
///   have been played yet. If the game uses handicap, handicap stones have
///   already been placed in this position.
/// - Board positions 1, 2, etc. refer to the position after move 1, 2, etc.
///   have been played.
///
///
/// @par Synchronization of current board position and object states
///
/// At any given time, the combined state of all the GoPoint and GoBoardRegion
/// objects attached to a GoGame instance describes how the Go board looks like
/// at that time.
///
/// Upon initialization, GoBoardPosition is associated with a GoGame instance.
/// The value of GoBoardPosition's @e currentBoardPosition property is in sync
/// at all times with the current state of the GoPoint and GoBoardRegion objects
/// attached to the GoGame instance.
///
///
/// @par Effects of synchronization
///
/// Changing the board position via the @e currentBoardPosition property
/// automatically updates the state of all associated GoPoint and GoBoardRegion
/// objects. Changing the board position in this way typically, but not
/// necessarily, occurs in response to user interaction (e.g. the user taps a
/// toolbar button to view the next/previous board position).
///
/// If the state of GoPoint and GoBoardRegion objects associated with a
/// GoBoardPosition instance changes, the value of the @e currentBoardPosition
/// property automatically changes to reflect the new state. Currently the only
/// event that triggers this is if a new move is made via one of the
/// move-generating methods in GoGame/ (GoGame::play:() and GoGame::pass()).
///
///
/// @par Notifications
///
/// Use KVO to observe @e currentBoardPosition and @e numberOfBoardPositions for
/// changes. In case both properties change their value in response to the same
/// event, the notification for @e numberOfBoardPositions is sent before the
/// notification for @e currentBoardPosition.
// -----------------------------------------------------------------------------
@interface GoBoardPosition : NSObject
{
}

- (id) initWithGame:(GoGame*)game;

/// @brief The current board position as described in the GoBoardPosition class
/// documentation.
///
/// Raises @e NSRangeException if a new board position is set that is <0 or
/// exceeds the number of moves in the GoGame associated with this
/// GoBoardPosition.
@property(nonatomic, assign) int currentBoardPosition;
/// @brief Returns the GoMove object that corresponds to
/// @e currentBoardPosition. Returns nil for board position 0.
@property(nonatomic, assign, readonly) GoMove* currentMove;
/// @brief Returns the player whose turn it is to play in the current board
/// position.
@property(nonatomic, assign, readonly) GoPlayer* currentPlayer;
/// @brief Returns true if it is the computer player's turn to play in the
/// current board position.
@property(nonatomic, assign, readonly) bool isComputerPlayersTurn;
/// @brief Returns true if the current board position is the first position of
/// the GoGame associated with this GoBoardPosition.
///
/// This is a convenience property that returns true if @e currentBoardPosition
/// equals 0.
@property(nonatomic, assign, readonly) bool isFirstPosition;
/// @brief Returns true if the current board position is the last position of
/// the GoGame associated with this GoBoardPosition.
///
/// This is a convenience property that returns true if the current board
/// position displays the last move of the game.
@property(nonatomic, assign, readonly) bool isLastPosition;
/// @brief The number of board positions in the GoGame associated with this
/// GoBoardPosition.
@property(nonatomic, assign, readonly) int numberOfBoardPositions;

@end
