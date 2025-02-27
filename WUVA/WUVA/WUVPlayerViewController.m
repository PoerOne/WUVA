//
//  ViewController.m
//  WUVA
//
//  Created by Alex Ramey on 10/27/15.
//  Copyright © 2015 Alex Ramey. All rights reserved.
//

#import "WUVPlayerViewController.h"
#import "WUVImageLoader.h"
#import "UIImageEffects.h"
#import <TritonPlayerSDK/TritonPlayerSDK.h>
#import "WUVFavorite.h"

@interface WUVPlayerViewController () <TritonPlayerDelegate>
@property (nonatomic, strong) TritonPlayer *tritonPlayer;
@property (nonatomic, weak) IBOutlet UIImageView *coverArt;
@property (nonatomic, weak) IBOutlet UIActivityIndicatorView *activityIndicator;
@property (nonatomic, strong) UIImageView *backgroundImage;
@property (nonatomic, strong) NSNumber *interruptedOnPlayback;
@property (nonatomic, weak) IBOutlet UIButton *play;
@property (nonatomic, weak) IBOutlet UILabel *artist;
@property (nonatomic, weak) IBOutlet UILabel *songTitle;
@property (nonatomic, weak) IBOutlet UIButton *favorite;
@property BOOL isCurrentlyPlayingSongFavorited;
@property BOOL isAlertUp;
@end


@implementation WUVPlayerViewController

NSString * const WUV_CACHED_IMAGE_KEY = @"WUV_CACHED_IMAGE_KEY";
NSString * const WUV_CACHED_IMAGE_ID_KEY = @"WUV_CACHED_IMAGE_ID_KEY";

// called when a new song is played, updates the favorite icon
- (void) updateFavoritesPlayerStateInformationForCurrentSong
{
    NSData *data = [[NSUserDefaults standardUserDefaults] objectForKey:@"WUV_FAVORITES_KEY"];
    if (data == nil)
    {
        _isCurrentlyPlayingSongFavorited = NO;
        [_favorite setBackgroundImage:[UIImage imageNamed:@"Unfavorite"] forState:UIControlStateNormal];
    }
    else
    {
        WUVFavorite *comparedObject = [[WUVFavorite alloc] init];
        comparedObject.artist = _artist.text;
        comparedObject.songTitle = _songTitle.text;
        NSMutableArray *objectArray = [[NSKeyedUnarchiver unarchiveObjectWithData:data] mutableCopy];
        if([objectArray containsObject:comparedObject])
        {
            _isCurrentlyPlayingSongFavorited = YES;
            [_favorite setBackgroundImage:[UIImage imageNamed:@"Favorite"] forState:UIControlStateNormal];
        }
        else
        {
            _isCurrentlyPlayingSongFavorited = NO;
            [_favorite setBackgroundImage:[UIImage imageNamed:@"Unfavorite"] forState:UIControlStateNormal];
        }
    }
    [self updateRemoteFavoriteIcon];
}

- (void)favoriteSong
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    if(_isCurrentlyPlayingSongFavorited == NO)
    {
        WUVFavorite *newObject = [WUVFavorite new];
        newObject.artist = _artist.text;
        newObject.songTitle = _songTitle.text;
        newObject.dateFavorited = [NSDate date];
        
        NSMutableArray *objectArray;
        NSData *data = [userDefaults objectForKey:@"WUV_FAVORITES_KEY"];
        if (data == nil)
        {
            objectArray = [NSMutableArray new];
            [objectArray insertObject:newObject atIndex:0];
        }
        else
        {
            objectArray = [[NSKeyedUnarchiver unarchiveObjectWithData:data] mutableCopy];
            [objectArray insertObject:newObject atIndex:0];

        }
        [userDefaults setObject:[NSKeyedArchiver archivedDataWithRootObject:objectArray] forKey:@"WUV_FAVORITES_KEY"];
        [userDefaults synchronize];

    }
    else/**_isFavorited == YES **/
    {
        WUVFavorite *deleteObject = [WUVFavorite new];
        deleteObject.artist = _artist.text;
        deleteObject.songTitle = _songTitle.text;
        
        NSMutableArray *objectArray;
        NSData *data = [userDefaults objectForKey:@"WUV_FAVORITES_KEY"];
        objectArray = [[NSKeyedUnarchiver unarchiveObjectWithData:data] mutableCopy];
        [objectArray removeObject:(WUVFavorite*)deleteObject];
        [userDefaults setObject:[NSKeyedArchiver archivedDataWithRootObject:objectArray] forKey:@"WUV_FAVORITES_KEY"];
        [userDefaults synchronize];
    }
    
    // quick fix to make favorites refresh after action from the control center
    UINavigationController *vc = self.tabBarController.viewControllers[1];
    [vc.viewControllers[0] viewWillAppear:YES];
}

- (void)updateRemoteFavoriteIcon
{
    MPRemoteCommandCenter *commandCenter = [MPRemoteCommandCenter sharedCommandCenter];
    commandCenter.likeCommand.active = NO;
    commandCenter.likeCommand.active = YES;
    if(_isCurrentlyPlayingSongFavorited == YES)
    {
        commandCenter.likeCommand.localizedTitle = @"Unfavorite";
    }
    else
    {
        commandCenter.likeCommand.localizedTitle = @"Add to Favorites";
    }
}

- (IBAction)favoriteButton:(id)sender
{
    if ([_tritonPlayer isExecuting])
    {
        [self favoriteSong];
        [self updateFavoritesPlayerStateInformationForCurrentSong];
    }
}

- (IBAction)share:(id)sender
{
    NSString *texttoshare;
    if (_songTitle.text && ([_songTitle.text compare:@" "] != NSOrderedSame))
    {
        texttoshare = [NSString stringWithFormat: @"Hey check out this awesome song, %@, by %@ I'm listening to on 92.7 Nash Icon", _songTitle.text, _artist.text];
    }
    else
    {
        texttoshare = @"Hey check out 92.7 Nash Icon, available now on your mobile device!";
    }
    NSArray *activityItems = @[texttoshare];
    UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:activityItems applicationActivities:nil];
    [self presentViewController:activityVC animated:TRUE completion:nil];
}

- (IBAction)playButton:(id)sender
{
    if ([self.tritonPlayer isExecuting]) {
        [self.tritonPlayer stop];
    }
    else{
        [self.tritonPlayer play];
    }
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    
    if (self)
    {
        self.interruptedOnPlayback = @NO;
        self.isAlertUp = NO;
        // initialize lock screen control and info parameters
        [self configureRemoteCommandHandling];
        [self configureNowPlayingInfo];
        
        NSDictionary *settings = @{SettingsStationNameKey : @"MOBILEFM",
                                   SettingsBroadcasterKey : @"Triton Digital",
                                   SettingsMountKey : @"WUVA"
                                   };
        self.tritonPlayer = [[TritonPlayer alloc] initWithDelegate:self andSettings: settings];
        
        [self.tritonPlayer play];
    }
    
    return self;
}

- (void)viewDidLayoutSubviews
{
    if (!_backgroundImage)
    {
        _backgroundImage = [[UIImageView alloc] initWithFrame:CGRectMake(0.0, 0.0, self.view.frame.size.width, self.view.frame.size.height)];
        // TODO: set backgroundImage.image to initially be the LaunchImage (once we have Launch Image).
        [self.view insertSubview:_backgroundImage atIndex:0];
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.navigationController.navigationBar setTranslucent:YES];
    self.navigationController.view.backgroundColor = [UIColor clearColor];
    [self.navigationController.navigationBar setBackgroundImage:[[UIImage alloc] init] forBarMetrics:UIBarMetricsDefault];
    self.navigationController.navigationBar.shadowImage = [[UIImage alloc] init];
    self.navigationController.navigationBar.backgroundColor = [UIColor clearColor];
    // the following line causes the status bar to be white
    [self.navigationController.navigationBar setBarStyle:UIBarStyleBlack];
    
    /* start the labels off as single-space strings so they aren't visible
     (the space is important so the labels don't collapse and cause lower 
     buttons to shift) */
    _artist.text = @" ";
    _songTitle.text = @" ";
    _artist.textColor = [UIColor whiteColor];
    _songTitle.textColor = [UIColor whiteColor];
    [_favorite setBackgroundImage:[UIImage imageNamed:@"Unfavorite"] forState:UIControlStateNormal];
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear: YES];
    [self.navigationController.navigationBar setTranslucent:YES];
    self.navigationController.view.backgroundColor = [UIColor clearColor];
    [self.navigationController.navigationBar setBackgroundImage:[[UIImage alloc] init] forBarMetrics:UIBarMetricsDefault];
    self.navigationController.navigationBar.shadowImage = [[UIImage alloc] init];
    self.navigationController.navigationBar.backgroundColor = [UIColor clearColor];
    // the following line causes the status bar to be white
    [self.navigationController.navigationBar setBarStyle:UIBarStyleBlack];
    [self updateFavoritesPlayerStateInformationForCurrentSong];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/* This method sets up handling for remote commands, like from the lock screen */
- (void)configureRemoteCommandHandling
{
    MPRemoteCommandCenter *commandCenter = [MPRemoteCommandCenter sharedCommandCenter];
    
    // register to receive remote play event
    [commandCenter.playCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent * _Nonnull event) {
        [_tritonPlayer play];
        return MPRemoteCommandHandlerStatusSuccess;
    }];
    
    // register to receive remote pause event
    [commandCenter.pauseCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent * _Nonnull event) {
        [_tritonPlayer stop];
        return MPRemoteCommandHandlerStatusSuccess;
    }];
    
    // register to receive remote like/favorite event
    commandCenter.likeCommand.localizedTitle = @"Add to Favorites";
    [commandCenter.likeCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent * _Nonnull event) {
        [self favoriteSong];
        [self updateFavoritesPlayerStateInformationForCurrentSong];
        return MPRemoteCommandHandlerStatusSuccess;
    }];
}

/* Here we wish to update the now playing info that will be displayed on the lock screen */
- (void)configureNowPlayingInfo
{
    MPNowPlayingInfoCenter* info = [MPNowPlayingInfoCenter defaultCenter];
    NSMutableDictionary* newInfo = [NSMutableDictionary dictionary];
    
    // Set song title info
    if (_songTitle.text && ([_songTitle.text compare:@" "] != NSOrderedSame))
    {
        [newInfo setObject:[NSString stringWithString:_songTitle.text] forKey:MPMediaItemPropertyTitle];
    }
    
    // Set artist info
    if (_artist.text && ([_artist.text compare:@"92.7 Nash Icon"] != NSOrderedSame))
    {
        NSString *artistInfo = [[NSString stringWithString:_artist.text] stringByAppendingString:@" - 92.7 Nash Icon"];
        [newInfo setObject:artistInfo forKey:MPMediaItemPropertyArtist];
    }
    else
    {
        // if we're here, then we're in the initial state or the pause state
        // We want 92.7 NashIcon to appear in the song title position
        [newInfo setObject:@"92.7 Nash Icon" forKey:MPMediaItemPropertyTitle];
    }
    
    // Update the now playing info
    info.nowPlayingInfo = newInfo;
}

/* This method updates the UI and NowPlayingInfo for the paused (or stopped) state */
- (void)showDefaults
{
    self.coverArt.image = [UIImage imageNamed:@"default_cover_art"];
    [self.coverArt setNeedsDisplay];
    [self updateBackgroundView];
    
    _artist.text = @"92.7 Nash Icon";
    _songTitle.text = @" ";         // make invisible but don't let label collapse
    [_favorite setBackgroundImage:[UIImage imageNamed:@"Unfavorite"] forState:UIControlStateNormal];
    [_favorite setEnabled:NO];
    
    [self configureNowPlayingInfo];
}

/* This method simply updates the background view to be the blur of _coverArt.image */
- (void)updateBackgroundView
{
    [_backgroundImage setImage:nil];
    if (_coverArt.image != nil)
    {
        UIColor *tintColor = [UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:.60];
        [_backgroundImage setImage:[UIImageEffects imageByApplyingBlurToImage:_coverArt.image withRadius:64 tintColor:tintColor saturationDeltaFactor:2.0 maskImage:nil]];
        [_backgroundImage setNeedsDisplay];
    }
}

/* 
 The following two methods are used to manage our single-image cache, which is used
 to help the UI quickly recover when the playing song doesn't change over the course
 of a pause state. In addition to saving the currently cached image, we save identifying
 information <song_title><arist_name> to help identify which image is currently in cache
*/
- (UIImage *)retrieveImageFromCacheForSong:(NSString *)song artist:(NSString *)artist
{
    NSString *currentlyCachedImageId = [[NSUserDefaults standardUserDefaults] objectForKey:WUV_CACHED_IMAGE_ID_KEY];
    
    if (!currentlyCachedImageId || !song || !artist)
    {
        return nil;
    }
    
    if ([[song stringByAppendingString:artist] compare:currentlyCachedImageId] == NSOrderedSame)
    {
        return [UIImage imageWithData:([[NSUserDefaults standardUserDefaults] objectForKey:WUV_CACHED_IMAGE_KEY])];
    }
    else
    {
        return nil;
    }
}

/* Here, we cache a given image with identifying song/artist params */
- (void)cacheImage:(UIImage *)image forSong:(NSString *)song artist:(NSString *)artist
{
    if (!image || !song || !artist)
    {
        return;
    }
    
    [[NSUserDefaults standardUserDefaults] setObject:[song stringByAppendingString:artist] forKey:WUV_CACHED_IMAGE_ID_KEY];
    [[NSUserDefaults standardUserDefaults] setObject:UIImagePNGRepresentation(image) forKey:WUV_CACHED_IMAGE_KEY];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)displayAlertWithTitle:(NSString *)title message:(NSString*)message
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.isAlertUp == NO)
        {
            self.isAlertUp = YES;
            UIAlertController *alertController = [UIAlertController
                                                  alertControllerWithTitle:title
                                                  message:message
                                                  preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction *okAction = [UIAlertAction
                                       actionWithTitle:@"OK"
                                       style:UIAlertActionStyleDefault
                                       handler:nil];
            [alertController addAction:okAction];
            [self presentViewController:alertController animated:YES completion:^{
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.isAlertUp = NO;
                });
            }];
        }
    });
}

#pragma mark TritonPlayerDelegate methods

- (void)player:(TritonPlayer *)player didReceiveCuePointEvent:(CuePointEvent *)cuePointEvent {
    // NSLog(@"Received CuePoint: %@", cuePointEvent.data);
    // Check if it's an ad or track cue point
    if ([cuePointEvent.type isEqualToString:EventTypeAd])
    {
        // Handle ad information (ex. pass to TDBannerView to render companion banner)
        // NSLog(@"Ad Cue Point!");
    }
    else if ([cuePointEvent.type isEqualToString:EventTypeTrack])
    {
        NSString *currentSongTitle = [cuePointEvent.data
                                      objectForKey:CommonCueTitleKey];
        NSString *currentArtistName = [cuePointEvent.data
                                       objectForKey:TrackArtistNameKey];
        
        _artist.text = currentArtistName;
        _songTitle.text = currentSongTitle;
        
        // checks to see if new song has been favorited
        [self updateFavoritesPlayerStateInformationForCurrentSong];
        
        // if cache retrieval fails, it will return nil.
        _coverArt.image = [self retrieveImageFromCacheForSong:currentSongTitle artist:currentArtistName];
        [_coverArt setNeedsDisplay];
        
        // immediately configure the NowPlayingInfo now that song,artist,image have changed
        [self configureNowPlayingInfo];
        
        // update the background view to reflect different _coverArt.image
        [self updateBackgroundView];
        
        if (!_coverArt.image)   //cache miss
        {
            [_activityIndicator startAnimating];
            WUVImageLoader *imageLoader = [WUVImageLoader new];
            [imageLoader loadImageForArtist:currentArtistName track:currentSongTitle completion:^(NSError *error, WUVRelease *release, NSString *artist, NSString *track) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    BOOL notRelevant = ([artist compare:_artist.text] != NSOrderedSame) ||
                    ([track compare:_songTitle.text] != NSOrderedSame);
                    
                    if (!notRelevant)
                    {
                        [_activityIndicator stopAnimating];
                    }
                    
                    if (!artist || !track)
                    {
                        // We passed a nil to the imageLoader for either artist or track.
                        // In this case, imageLoader didn't do anything. This can happen
                        // if a cuePoint comes in without track/artist info.
                        return;
                    }
                    else if (notRelevant)
                    {
                        // song has changed. These results are no longer relevant.
                        return;
                    }
                    else if (!release)
                    {
                        // load default
                        self.coverArt.image = [UIImage imageNamed:@"default_cover_art"];
                        [self.coverArt setNeedsDisplay];
                        [self configureNowPlayingInfo];
                        [self updateBackgroundView];
                        
                        // if (error){NSLog(@"%@", error);}
                    }
                    else
                    {
                        self.coverArt.image = [UIImage imageWithData:release.artwork];
                        [self.coverArt setNeedsDisplay];
                        [self configureNowPlayingInfo];
                        [self updateBackgroundView];
                        // cache the fetched image
                        [self cacheImage:self.coverArt.image forSong:currentSongTitle artist:currentArtistName];
                    }
                });
            }];
        }
    }
}

-(void)player:(TritonPlayer *)player didChangeState:(TDPlayerState)state {
    switch (state) {
        case kTDPlayerStateConnecting:
            // NSLog(@"State: Connecting");
            break;
        case kTDPlayerStatePlaying:
            // NSLog(@"Status: Playing");
            [_play setBackgroundImage:[UIImage imageNamed:@"PauseIcon"] forState:UIControlStateNormal];
            [_favorite setEnabled:YES];
            [MPRemoteCommandCenter sharedCommandCenter].likeCommand.enabled = YES;
            break;
        case kTDPlayerStateStopped:
            // NSLog(@"State: Stopped");
             [_play setBackgroundImage:[UIImage imageNamed:@"PlayIcon"] forState:UIControlStateNormal];
            [MPRemoteCommandCenter sharedCommandCenter].likeCommand.enabled = NO;
            [self showDefaults];
            break;
        case kTDPlayerStateError:
            // NSLog(@"State: Error");
            [self displayAlertWithTitle:@"Player Error" message:@"Unable to connect at this time. Please try again later."];
            // quick fix for the "invisible play button" after player initially
            // fails to connect (like when user is in airplane mode when they launch
            // the app)
            [_play setBackgroundImage:[UIImage imageNamed:@"PlayIcon"] forState:UIControlStateNormal];
            break;
        case kTDPlayerStatePaused:
            // NSLog(@"State: Paused");
            [_play setBackgroundImage:[UIImage imageNamed:@"PlayIcon"] forState:UIControlStateNormal];
            [MPRemoteCommandCenter sharedCommandCenter].likeCommand.enabled = NO;
            [self showDefaults];
            break;
        default:
            break;
    }
}

-(void)player:(TritonPlayer *)player didReceiveInfo:(TDPlayerInfo)info andExtra:(NSDictionary *)extra {
    
    switch (info) {
        case kTDPlayerInfoConnectedToStream:
            // NSLog(@"Connected to stream");
            break;
            
        case kTDPlayerInfoBuffering:
            // NSLog(@"Buffering %@%%...", extra[InfoBufferingPercentageKey]);
            break;
            
        case kTDPlayerInfoForwardedToAlternateMount:
            // NSLog(@"Forwarded to an alternate mount: %@", extra[InfoAlternateMountNameKey]);
            break;
    }
}

- (void)playerBeginInterruption:(TritonPlayer *) player {
    // NSLog(@"playerBeginInterruption");
    if ([self.tritonPlayer isExecuting]) {
        [self.tritonPlayer stop];
        self.interruptedOnPlayback = @YES;
    }
}

- (void)playerEndInterruption:(TritonPlayer *) player {
    // NSLog(@"playerEndInterruption");
    if ([self.interruptedOnPlayback boolValue] && player.shouldResumePlaybackAfterInterruption) {
        // NSLog(@"Resume Stream!");
        // Resume stream
        [self.tritonPlayer play];
        self.interruptedOnPlayback = @NO;
    }
}

@end
