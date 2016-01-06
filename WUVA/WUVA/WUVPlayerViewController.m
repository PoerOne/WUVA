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
@import MediaPlayer;

@interface WUVPlayerViewController () <TritonPlayerDelegate>
@property (nonatomic, strong) TritonPlayer *tritonPlayer;
@property (nonatomic, strong) WUVImageLoader *imageLoader;
@property (nonatomic, weak) IBOutlet UIImageView *coverArt;
@property (nonatomic, strong) UIImageView *backgroundImage;
@property (nonatomic, strong) NSNumber *interruptedOnPlayback;
@property (nonatomic, weak) IBOutlet UIButton *play;
@property (nonatomic, weak) IBOutlet UILabel *artist;
@property (nonatomic, weak) IBOutlet UILabel *songTitle;
@property (nonatomic, weak) IBOutlet UIButton *favorite;
@property BOOL isFavorited;
@end


@implementation WUVPlayerViewController

NSString * const WUV_CACHED_IMAGE_KEY = @"WUV_CACHED_IMAGE_KEY";
NSString * const WUV_CACHED_IMAGE_ID_KEY = @"WUV_CACHED_IMAGE_ID_KEY";

- (void) isSongFavorited{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSMutableArray *arrayOfTitles = [userDefaults objectForKey:@"Title"];
    if([arrayOfTitles containsObject:_songTitle.text]){
        _isFavorited = YES;
        [_favorite setBackgroundImage:[UIImage imageNamed:@"Favorite"] forState:UIControlStateNormal];
    }else{
        _isFavorited = NO;
        [_favorite setBackgroundImage:[UIImage imageNamed:@"Unfavorite"] forState:UIControlStateNormal];
    }

}

- (IBAction)favoriteSong:(id)sender
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    
    if(_isFavorited == NO){
        // update the favorite icon
        [_favorite setBackgroundImage:[UIImage imageNamed:@"Favorite"] forState:UIControlStateNormal];
        _isFavorited = YES;
        NSMutableArray *arrayOfTitles = [userDefaults objectForKey:@"Title"];
        if(arrayOfTitles != nil){
//            NSMutableArray *arrayOfImages = [userDefaults objectForKey:@"Image"];
            NSMutableArray *arrayOfArtists = [[userDefaults objectForKey:@"Artist"] mutableCopy];
            NSMutableArray *arrayOfTitles = [[userDefaults objectForKey:@"Title"] mutableCopy];
            
//            [arrayOfImages insertObject:_backgroundImage.image atIndex:0];
            [arrayOfArtists insertObject:_artist.text atIndex:0];
            [arrayOfTitles insertObject:_songTitle.text atIndex:0];
            
//            [userDefaults setObject:arrayOfImages forKey:@"Image"];
            [userDefaults setObject:arrayOfArtists forKey:@"Artist"];
            [userDefaults setObject:arrayOfTitles forKey:@"Title"];
            
            [userDefaults synchronize];

        }else{
//            NSMutableArray *arrayOfImages = [NSMutableArray new];
            NSMutableArray *arrayOfArtists = [NSMutableArray new];
            NSMutableArray *arrayOfTitles = [NSMutableArray new];
            
//            [arrayOfImages insertObject:_backgroundImage.image atIndex:0];
            [arrayOfArtists insertObject:_artist.text atIndex:0];
            [arrayOfTitles insertObject:_songTitle.text atIndex:0];
            
//            [userDefaults setObject:arrayOfImages forKey:@"Image"];
            [userDefaults setObject:arrayOfArtists forKey:@"Artist"];
            [userDefaults setObject:arrayOfTitles forKey:@"Title"];
            
            [userDefaults synchronize];
        }
        
        
        
    }else/**_isFavorited == YES **/{
        // update the favorite icon
        [_favorite setBackgroundImage:[UIImage imageNamed:@"Unfavorite"] forState:UIControlStateNormal];
        _isFavorited = NO;
        
//        NSMutableArray *arrayOfImages = [userDefaults objectForKey:@"Image"];
        NSMutableArray *arrayOfArtists = [[userDefaults objectForKey:@"Artist"] mutableCopy];
        NSMutableArray *arrayOfTitles = [[userDefaults objectForKey:@"Title"] mutableCopy];
        
//        [arrayOfImages removeObject:_backgroundImage.image];
        [arrayOfArtists removeObject:_artist.text];
        [arrayOfTitles removeObject:_songTitle.text];
        
//        [userDefaults setObject:arrayOfImages forKey:@"Image"];
        [userDefaults setObject:arrayOfArtists forKey:@"Artist"];
        [userDefaults setObject:arrayOfTitles forKey:@"Title"];
        
        [userDefaults synchronize];
        
    }

}

- (IBAction)share:(id)sender
{
    NSString *texttoshare = [NSString stringWithFormat: @"Hey check out this awesome song, %@, by %@ I'm listening to on WUVA 92.7", _songTitle.text, _artist.text];
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
        self.imageLoader = [WUVImageLoader new];
        self.interruptedOnPlayback = @NO;
        
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
    commandCenter.likeCommand.localizedTitle = @"Favorite";
    [commandCenter.likeCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent * _Nonnull event) {
        NSLog(@"Mr. Jeffrey, this hook may be of interest to you.");
        // TODO: Implement Logic to figure out if current song is already favorited.
        // If so, localizedTitle should be Unfavorite and this btn should unfavorite it.
        // else, localizedTitle should be Favorite and this btn should favorite it.
        // After action is complete, localizedTitle should be toggled
        return MPRemoteCommandHandlerStatusSuccess;
    }];
}

/* Here we wish to update the now playing info that will be displayed on the lock screen */
- (void)configureNowPlayingInfo
{
    MPNowPlayingInfoCenter* info = [MPNowPlayingInfoCenter defaultCenter];
    NSMutableDictionary* newInfo = [NSMutableDictionary dictionary];
    
    // Set song title info
    if (_songTitle.text)
    {
        [newInfo setObject:[NSString stringWithString:_songTitle.text] forKey:MPMediaItemPropertyTitle];
    }
    else
    {
        [newInfo setObject:@" " forKey:MPMediaItemPropertyTitle];
    }
    
    // Set artist info
    if (_artist.text && ([_artist.text caseInsensitiveCompare:@"WUVA 92.7"] != NSOrderedSame))
    {
        NSString *artistInfo = [[NSString stringWithString:_artist.text] stringByAppendingString:@" - WUVA 92.7"];
        [newInfo setObject:artistInfo forKey:MPMediaItemPropertyArtist];
    }
    else
    {
        [newInfo setObject:@"WUVA 92.7" forKey:MPMediaItemPropertyArtist];
    }
    
    // Set album art info
    if (_coverArt.image)
    {
        MPMediaItemArtwork *albumArt = [[MPMediaItemArtwork alloc] initWithImage:_coverArt.image];
        [newInfo setObject:albumArt forKey:MPMediaItemPropertyArtwork];
    }
    
    // Update the now playing info
    info.nowPlayingInfo = newInfo;
}

/* This method updates the UI and NowPlayingInfo for the paused (or stopped) state */
- (void)showPausedUI
{
    self.coverArt.image = [UIImage imageNamed:@"default_cover_art"];
    [self.coverArt setNeedsDisplay];
    [self updateBackgroundView];
    
    _artist.text = @"WUVA 92.7";
    _songTitle.text = @" ";         // make invisible but don't let label collapse
    
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
}

#pragma mark TritonPlayerDelegate methods

- (void)player:(TritonPlayer *)player didReceiveCuePointEvent:(CuePointEvent *)cuePointEvent {
    NSLog(@"Received CuePoint: %@", cuePointEvent);
    // Check if it's an ad or track cue point
    if ([cuePointEvent.type isEqualToString:EventTypeAd]) {
        // Handle ad information (ex. pass to TDBannerView to render companion banner)
        NSLog(@"Ad Cue Point!");
    } else if ([cuePointEvent.type isEqualToString:EventTypeTrack]) {
        NSString *currentSongTitle = [cuePointEvent.data
                                      objectForKey:CommonCueTitleKey];
        NSString *currentArtistName = [cuePointEvent.data
                                       objectForKey:TrackArtistNameKey];
        
        _artist.text = currentArtistName;
        _songTitle.text = currentSongTitle;
        [self isSongFavorited];
        
        // if cache retrieval fails, it will return nil.
        _coverArt.image = [self retrieveImageFromCacheForSong:currentSongTitle artist:currentArtistName];
        [_coverArt setNeedsDisplay];
        
        // immediately configure the NowPlayingInfo now that song,artist,image have changed
        [self configureNowPlayingInfo];
        
        // update the background view to reflect different _coverArt.image
        [self updateBackgroundView];
        
        if (!_coverArt.image)   //cache miss
        {
            [self.imageLoader loadImageForArtist:currentArtistName track:currentSongTitle completion:^(NSError *error, WUVRelease *release) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (!release)
                    {
                        // load default
                        self.coverArt.image = [UIImage imageNamed:@"default_cover_art"];
                        [self.coverArt setNeedsDisplay];
                        [self updateBackgroundView];
                        
                        if (error){NSLog(@"%@", error);}
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
            NSLog(@"State: Connecting");
            break;
        case kTDPlayerStatePlaying:
            NSLog(@"Status: Playing");
            [_play setBackgroundImage:[UIImage imageNamed:@"PauseIcon"] forState:UIControlStateNormal];
            break;
        case kTDPlayerStateStopped:
            NSLog(@"State: Stopped");
             [_play setBackgroundImage:[UIImage imageNamed:@"PlayIcon"] forState:UIControlStateNormal];
            [self showPausedUI];
            break;
        case kTDPlayerStateError:
            NSLog(@"State: Error");
            break;
        case kTDPlayerStatePaused:
            NSLog(@"State: Paused");
            [_play setBackgroundImage:[UIImage imageNamed:@"PlayIcon"] forState:UIControlStateNormal];
            [self showPausedUI];
            break;
        default:
            break;
    }
}

-(void)player:(TritonPlayer *)player didReceiveInfo:(TDPlayerInfo)info andExtra:(NSDictionary *)extra {
    
    switch (info) {
        case kTDPlayerInfoConnectedToStream:
            NSLog(@"Connected to stream");
            break;
            
        case kTDPlayerInfoBuffering:
            NSLog(@"Buffering %@%%...", extra[InfoBufferingPercentageKey]);
            break;
            
        case kTDPlayerInfoForwardedToAlternateMount:
            NSLog(@"Forwarded to an alternate mount: %@", extra[InfoAlternateMountNameKey]);
            break;
    }
}

- (void)playerBeginInterruption:(TritonPlayer *) player {
    NSLog(@"playerBeginInterruption");
    if ([self.tritonPlayer isExecuting]) {
        [self.tritonPlayer stop];
        self.interruptedOnPlayback = @YES;
    }
}

- (void)playerEndInterruption:(TritonPlayer *) player {
    NSLog(@"playerEndInterruption");
    if ([self.interruptedOnPlayback boolValue] && player.shouldResumePlaybackAfterInterruption) {
        NSLog(@"Resume Stream!");
        // Resume stream
        [self.tritonPlayer play];
        self.interruptedOnPlayback = @NO;
    }
}

@end
