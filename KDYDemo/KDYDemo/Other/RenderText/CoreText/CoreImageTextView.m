//
//  CoreImageTextView.m
//  KDYDemo
//
//  Created by kaideyi on 16/1/2.
//  Copyright © 2016年 kaideyi.com. All rights reserved.
//

#import "CoreImageTextView.h"
#import "SDWebImageManager.h"
#import <CoreText/CoreText.h>

@implementation CoreImageTextView

- (void)drawRect:(CGRect)rect {
    [super drawRect:rect];
    
    //文本与图片混排
    [self setupImageText];
}


/**
 图片的代理方法里主要是区别了本地图片和网络图片的宽高返回方式。
 本地图片因为在内存里可以直接读取，网络图片则是在设置代理时用服务端返回的宽高字段的。
 */
#pragma mark - 图片代理
void RunDelegateDeallocCallback(void *refCon) {
    NSLog(@"RunDelegate dealloc");
}

CGFloat RunDelegateGetAscentCallback(void *refCon) {
    NSString *imageName = (__bridge NSString *)refCon;
    if ([imageName isKindOfClass:[NSString class]]) {
        //对应本地图片
        return [UIImage imageNamed:imageName].size.height;
    }
    
    //对应网络图片
    return [[(__bridge NSDictionary *)refCon objectForKey:@"height"] floatValue];
}

CGFloat RunDelegateGetDescentCallback(void *refCon) {
    return 0;
}

CGFloat RunDelegateGetWidthCallback(void *refCon) {
    NSString *imageName = (__bridge NSString *)refCon;
    if ([imageName isKindOfClass:[NSString class]]) {
        // 本地图片
        return [UIImage imageNamed:imageName].size.width;
    }
    
    //对应网络图片
    return [[(__bridge NSDictionary *)refCon objectForKey:@"width"] floatValue];
}

#pragma mark - 图文混排
- (void)downLoadImageWithURL:(NSURL *)url {
    __weak typeof(self) weakSelf = self;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        SDWebImageOptions options = SDWebImageRetryFailed | SDWebImageHandleCookies | SDWebImageContinueInBackground;
        options = SDWebImageRetryFailed | SDWebImageContinueInBackground;
        [[SDWebImageManager sharedManager] downloadImageWithURL:url options:options progress:nil completed:^(UIImage *image, NSError *error, SDImageCacheType cacheType, BOOL finished, NSURL *imageURL) {
            
            weakSelf.image = image;
            dispatch_async(dispatch_get_main_queue(), ^{
                if (weakSelf.image) {
                    [self setNeedsDisplay];
                }
            });
        }];
    });
}

- (void)setupImageText {
    //1.获取上下文
    CGContextRef contextRef = UIGraphicsGetCurrentContext();
    
    //[a,b,c,d,tx,ty]
    NSLog(@"转换前的坐标：%@",NSStringFromCGAffineTransform(CGContextGetCTM(contextRef)));
    
    //2.转换坐标系
    CGContextSetTextMatrix(contextRef, CGAffineTransformIdentity);
    CGContextTranslateCTM(contextRef, 0, self.bounds.size.height);
    CGContextScaleCTM(contextRef, 1.0, -1.0);
    NSLog(@"转换后的坐标：%@",NSStringFromCGAffineTransform(CGContextGetCTM(contextRef)));
    
    //3.创建绘制区域，可以对path进行个性化裁剪以改变显示区域
    CGMutablePathRef path = CGPathCreateMutable();
    CGPathAddRect(path, NULL, self.bounds);
    
    //4.创建需要绘制的文字
    NSString *textStr = @"在iOS 8及之后的版本中，使用HealthKit构建的应用可以利用从健康应用中获取的数据为用户提供更强大、更完整的健康及健身服务。在用户允许的情况下，应用可以通过HealthKit来读写健康应用(用户健康相关数据的存储中心)中的数据。";
    NSMutableAttributedString *attTextString = [[NSMutableAttributedString alloc] initWithString:textStr];
    
    //设置字体大小和字体颜色
    [attTextString addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:20] range:NSMakeRange(0, 5)];
    [attTextString addAttribute:NSForegroundColorAttributeName value:[UIColor redColor] range:NSMakeRange(4, 10)];
    [attTextString addAttribute:(id)kCTForegroundColorAttributeName value:[UIColor greenColor] range:NSMakeRange(0, 4)];
    
    //设置行距等样式
    CGFloat lineSpace = 5;
    CGFloat lineSpaceMax = 10;
    CGFloat lineSpaceMin = 2;
    const CFIndex kNumberOfSettings = 3;
    
    CTParagraphStyleSetting theSettings[kNumberOfSettings] = {
        {kCTParagraphStyleSpecifierLineSpacingAdjustment, sizeof(CGFloat), &lineSpace},
        {kCTParagraphStyleSpecifierMaximumLineSpacing, sizeof(CGFloat), &lineSpaceMax},
        {kCTParagraphStyleSpecifierMinimumLineSpacing, sizeof(CGFloat), &lineSpaceMin}
    };
    
    CTParagraphStyleRef theParagraphRef = CTParagraphStyleCreate(theSettings, kNumberOfSettings);
    [attTextString addAttribute:(id)kCTParagraphStyleAttributeName value:(__bridge id)theParagraphRef range:NSMakeRange(0, attTextString.length)];
    [attTextString addAttribute:NSParagraphStyleAttributeName value:(__bridge id)(theParagraphRef) range:NSMakeRange(0, attTextString.length)];
    CFRelease(theParagraphRef);
    
    //插入图片部分
    //为图片设置CTRunDelegate，delegate决定留给图片的空间大小
    NSString *weicaiImageName = @"about";
    CTRunDelegateCallbacks imageCallbacks;
    imageCallbacks.version = kCTRunDelegateVersion1;
    imageCallbacks.dealloc = RunDelegateDeallocCallback;
    imageCallbacks.getAscent = RunDelegateGetAscentCallback;
    imageCallbacks.getDescent = RunDelegateGetDescentCallback;
    imageCallbacks.getWidth = RunDelegateGetWidthCallback;
    
    //①该方式适用于图片在本地的情况
    //设置CTRun的代理
    CTRunDelegateRef runDelegate = CTRunDelegateCreate(&imageCallbacks, (__bridge void *)(weicaiImageName));
    //空格用于给图片留位置
    NSMutableAttributedString *imageAttributedString = [[NSMutableAttributedString alloc] initWithString:@" "];
    
    [imageAttributedString addAttribute:(NSString *)kCTRunDelegateAttributeName value:(__bridge id)runDelegate range:NSMakeRange(0, 1)];
    CFRelease(runDelegate);
    [imageAttributedString addAttribute:@"imageName" value:weicaiImageName range:NSMakeRange(0, 1)];
    
    //在index处插入图片，可插入多张
    [attTextString insertAttributedString:imageAttributedString atIndex:5];
    //    [attributed insertAttributedString:imageAttributedString atIndex:10];
    
    //②若图片资源在网络上，则需要使用0xFFFC作为占位符
    //图片信息字典
    NSString *picURL = @"http://weicai-hearsay-avatar.qiniudn.com/b4f71f05a1b7593e05e91b0175bd7c9e?imageView2/2/w/192/h/277";
    NSDictionary *imgInfoDic = @{@"width":@192,@"height":@277};  //宽高跟具体图片有关
    //设置CTRun的代理
    CTRunDelegateRef delegate = CTRunDelegateCreate(&imageCallbacks, (__bridge void *)imgInfoDic);
    
    //使用0xFFFC作为空白的占位符
    unichar objectReplacementChar = 0xFFFC;
    NSString *content = [NSString stringWithCharacters:&objectReplacementChar length:1];
    NSMutableAttributedString *space = [[NSMutableAttributedString alloc] initWithString:content];
    CFAttributedStringSetAttribute((CFMutableAttributedStringRef)space, CFRangeMake(0, 1), kCTRunDelegateAttributeName, delegate);
    CFRelease(delegate);
    
    //将创建的空白AttributedString插入进当前的attrString中，位置可以随便指定，不能越界
    [attTextString insertAttributedString:space atIndex:10];
    
    //5.根据NSAttributedString生成CTFramesetterRef
    CTFramesetterRef framesetter = CTFramesetterCreateWithAttributedString((CFAttributedStringRef)attTextString);
    CTFrameRef ctFrame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, attTextString.length), path, NULL);
    
    //6.绘制除图片以外的部分
    CTFrameDraw(ctFrame, contextRef);
    
    //处理绘制图片的逻辑
    CFArrayRef lines = CTFrameGetLines(ctFrame);
    CGPoint lineOrigins[CFArrayGetCount(lines)];
    
    //把ctFrame里每一行的初始坐标写到数组里
    CTFrameGetLineOrigins(ctFrame, CFRangeMake(0, 0), lineOrigins);
    
    //遍历CTRun找出图片所在的CTRun并进行绘制
    for (int i = 0; i < CFArrayGetCount(lines); i++) {
        //遍历每一行CTLine
        CTLineRef line = CFArrayGetValueAtIndex(lines, i);
        CGFloat lineAscent;
        CGFloat lineDescent;
        CGFloat lineLeading;  //行距
        CTLineGetTypographicBounds(line, &lineAscent, &lineDescent, &lineLeading);
        
        CFArrayRef runs = CTLineGetGlyphRuns(line);
        for (int j = 0; j < CFArrayGetCount(runs); j++) {
            //遍历每一个CTRun
            CGFloat runAscent;
            CGFloat runDescent;
            CGPoint lineOrigin = lineOrigins[i]; // 获取该行的初始坐标
            CTRunRef run = CFArrayGetValueAtIndex(runs, j); // 获取当前的CTRun
            NSDictionary* attributes = (NSDictionary*)CTRunGetAttributes(run);
            CGRect runRect;
            runRect.size.width = CTRunGetTypographicBounds(run, CFRangeMake(0,0), &runAscent, &runDescent, NULL);
            
            //这一段可参考Nimbus的NIAttributedLabel
            runRect = CGRectMake(lineOrigin.x + CTLineGetOffsetForStringIndex(line, CTRunGetStringRange(run).location, NULL), lineOrigin.y - runDescent, runRect.size.width, runAscent + runDescent);
            NSString *imageName = [attributes objectForKey:@"imageName"];
            
            if ([imageName isKindOfClass:[NSString class]]) {
                // 绘制本地图片
                UIImage *image = [UIImage imageNamed:imageName];
                CGRect imageDrawRect;
                imageDrawRect.size = image.size;
                NSLog(@"%.2f",lineOrigin.x); // 该值是0,runRect已经计算过起始值
                imageDrawRect.origin.x = runRect.origin.x;// + lineOrigin.x;
                imageDrawRect.origin.y = lineOrigin.y;
                CGContextDrawImage(contextRef, imageDrawRect, image.CGImage);
                
            } else {
                imageName = nil;
                
                CTRunDelegateRef delegate = (__bridge CTRunDelegateRef)[attributes objectForKey:(__bridge id)kCTRunDelegateAttributeName];
                if (!delegate) {
                    continue; // 如果是非图片的CTRun则跳过
                }
                
                //网络图片
                UIImage *image;
                if (!self.image) {
                    //图片未下载完成，使用占位图片
                    image = [UIImage imageNamed:weicaiImageName];
                    
                    //去下载图片
                    [self downLoadImageWithURL:[NSURL URLWithString:picURL]];
                } else {
                    image = self.image;
                }
                
                //绘制网络图片
                CGRect imageDrawRect;
                imageDrawRect.size = image.size;
                NSLog(@"%.2f",lineOrigin.x); // 该值是0,runRect已经计算过起始值
                imageDrawRect.origin.x = runRect.origin.x;// + lineOrigin.x;
                imageDrawRect.origin.y = lineOrigin.y;
                CGContextDrawImage(contextRef, imageDrawRect, image.CGImage);
            }
        }
    }

    CFRelease(path);
    CFRelease(framesetter);
    CFRelease(ctFrame);
}

@end

