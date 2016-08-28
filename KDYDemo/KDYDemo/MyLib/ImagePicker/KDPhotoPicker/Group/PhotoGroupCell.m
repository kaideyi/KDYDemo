//
//  PhotoGroupCell.m
//  KDYDemo
//
//  Created by zhongye on 16/2/25.
//  Copyright © 2016年 kaideyi.com. All rights reserved.
//

#import "PhotoGroupCell.h"

@implementation PhotoGroupCell

- (void)bind:(ALAssetsGroup *)assetsGroup {
    if (self.groupImageView == nil) {
        UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(14, 5, 50, 50)];
        [self.contentView addSubview:imageView];
        self.groupImageView = imageView;
    }
    
    if (self.groupTextLabel == nil) {
        UILabel *textLabel = [[UILabel alloc] initWithFrame:CGRectMake(70, self.bounds.size.height/2-10, [UIScreen mainScreen].bounds.size.width-70, 20)];
        textLabel.font = [UIFont systemFontOfSize:15];
        textLabel.backgroundColor = [UIColor clearColor];
        [self.contentView addSubview:textLabel];
        self.groupTextLabel = textLabel;
    }
    
    CGImageRef posterImage = assetsGroup.posterImage;
    size_t height = CGImageGetHeight(posterImage);
    float scale = height / 78.0f;
    
    self.groupImageView.image = [UIImage imageWithCGImage:posterImage scale:scale orientation:UIImageOrientationUp];
    self.groupTextLabel.text = [NSString stringWithFormat:@"%@(%ld)", [assetsGroup valueForProperty:ALAssetsGroupPropertyName], (long)[assetsGroup numberOfAssets]];
}

@end

