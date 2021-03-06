//
//  WBStatusLayout.m
//  KDYDemo
//
//  Created by zhongye on 15/12/25.
//  Copyright © 2015年 kaideyi.com. All rights reserved.
//

#import "WBStatusLayout.h"
#import "WBStatusHelper.h"

/*
 将每行的 baseline 位置固定下来，不受不同字体的 ascent/descent 影响。
 
 注意，Heiti SC 中，    ascent + descent = font size，
 但是在 PingFang SC 中，ascent + descent > font size。
 所以这里统一用 Heiti SC (0.86 ascent, 0.14 descent) 作为顶部和底部标准，保证不同系统下的显示一致性。
 间距仍然用字体默认
 */
#pragma mark -
@implementation WBTextLinePositionModifier
- (instancetype)init {
    self = [super init];
    
    if (kiOS9Later) {
        _lineHeightMultiple = 1.34;   // for PingFang SC
    } else {
        _lineHeightMultiple = 1.3125; // for Heiti SC
    }
    
    return self;
}

- (void)modifyLines:(NSArray *)lines fromText:(NSAttributedString *)text inContainer:(YYTextContainer *)container {
    //CGFloat ascent = _font.ascender;
    CGFloat ascent = _font.pointSize * 0.86;
    
    CGFloat lineHeight = _font.pointSize * _lineHeightMultiple;
    for (YYTextLine *line in lines) {
        CGPoint position = line.position;
        position.y = _paddingTop + ascent + line.row  * lineHeight;
        line.position = position;
    }
}

- (id)copyWithZone:(NSZone *)zone {
    WBTextLinePositionModifier *one = [self.class new];
    one->_font = _font;
    one->_paddingTop = _paddingTop;
    one->_paddingBottom = _paddingBottom;
    one->_lineHeightMultiple = _lineHeightMultiple;
    return one;
}

- (CGFloat)heightForLineCount:(NSUInteger)lineCount {
    if (lineCount == 0) return 0;
    
    CGFloat ascent = _font.pointSize * 0.86;
    CGFloat descent = _font.pointSize * 0.14;
    CGFloat lineHeight = _font.pointSize * _lineHeightMultiple;
    return _paddingTop + _paddingBottom + ascent + descent + (lineCount - 1) * lineHeight;
}

@end

/**
 微博的文本中，某些嵌入的图片需要从网上下载，这里简单做个封装
 */
#pragma mark -
@interface WBTextImageViewAttachment : YYTextAttachment
@property (nonatomic, strong) NSURL *imageURL;
@property (nonatomic, assign) CGSize size;

@end

@implementation WBTextImageViewAttachment {
    UIImageView *_imageView;
}
- (void)setContent:(id)content {
    _imageView = content;
}
- (id)content {
    /// UIImageView 只能在主线程访问
    if (pthread_main_np() == 0) return nil;
    if (_imageView) return _imageView;
    
    /// 第一次获取时 (应该是在文本渲染完成，需要添加附件视图时)，初始化图片视图，并下载图片
    /// 这里改成 YYAnimatedImageView 就能支持 GIF/APNG/WebP 动画了
    _imageView = [UIImageView new];
    _imageView.size = _size;
    [_imageView setImageWithURL:_imageURL placeholder:nil];
    return _imageView;
}
@end

@implementation WBStatusLayout
#pragma mark - Life Cycle
- (instancetype)initWithStatus:(WBStatus *)status style:(WBLayoutStyle)style {
    if (!status || !status.user)  {
        return nil;
    }
    self = [super init];
    if (self) {
        _status = status;
        _style = style;
        [self setupLayout];
    }
    
    return self;
}

- (void)setupLayout {
    [self _setupLayout];
}

- (void)updateDate {
    
}

- (void)_setupLayout {
    _marginTop = kWBCellTopMargin;
    _titleHeight = 0;
    _profileHeight = 0;
    _textHeight = 0;
    _retweetHeight = 0;
    _retweetTextHeight = 0;
    _retweetPicHeight = 0;
    _retweetCardHeight = 0;
    _picHeight = 0;
    _cardHeight = 0;
    _toolbarHeight = kWBCellToolbarHeight;
    _marginBottom = kWBCellToolbarBottomMargin;
    
    //内容排版，计算布局
    [self _layoutTitle];
    [self _layoutProfile];
    [self _layoutRetweet];

    //当没有转发微博时，布局图片；若没有发图片，则会布局卡片
    if (_retweetHeight == 0) {
        [self _layoutPics];
        if (_picHeight == 0) {
            [self _layoutCard];
        }
    }
    
    [self _layoutText];
    [self _layoutTag];
    [self _layoutToolBar];
    
    //通过上面的布局计算好每个view的高度，最张得到总高度
    _totalHeight = 0;
    _totalHeight += _marginTop;
    _totalHeight += _titleHeight;
    _totalHeight += _profileHeight;
    _totalHeight += _textHeight;
    
    if (_retweetHeight > 0) {
        _totalHeight += _retweetHeight;
    } else if (_picHeight > 0) {
        _totalHeight += _picHeight;
    } else if (_cardHeight > 0) {
        _totalHeight += _cardHeight;
    }
    
    if (_tagHeight > 0) {
        _totalHeight += _tagHeight;
    } else {
        if (_picHeight > 0 || _cardHeight > 0) {
            _totalHeight += kWBCellPadding;
        }
    }
    
    _totalHeight += _toolbarHeight;
    _totalHeight += _marginBottom;
}

#pragma mark - Layout
///布局微博标题
- (void)_layoutTitle {
    _titleHeight = 0;
    _titleTextLayout = nil;
    
    WBStatusTitle *title = _status.title;
    if (title.text.length == 0) {
        return;
    }
    
    NSMutableAttributedString *text = [[NSMutableAttributedString alloc] initWithString:title.text];
    if (title.iconURL) {
        
    }
    text.color = kWBCellToolbarTitleColor;
    text.font = [UIFont systemFontOfSize:kWBCellTitlebarFontSize];
    
    YYTextContainer *container = [YYTextContainer containerWithSize:CGSizeMake(kScreenWidth-100, kWBCellTitleHeight)];
    _titleTextLayout = [YYTextLayout layoutWithContainer:container text:text];
    _titleHeight = kWBCellTitleHeight;
}

///布局个人资料
- (void)_layoutProfile {
    [self _layoutName];
    [self _layoutSource];
    
    _profileHeight = kWBCellProfileHeight;
}

///布局用户名
- (void)_layoutName {
    WBUser *user = _status.user;
    NSString *nameStr = nil;
    if (user.remark.length) {
        nameStr = user.remark;
    } else if (user.screenName.length) {
        nameStr = user.screenName;
    } else {
        nameStr = user.name;
    }
    
    if (nameStr.length == 0) {
        _nameTextLayout = nil;
        return;
    }
    
    //将昵称和等级图标作为一个可变字符串
    NSMutableAttributedString *nameText = [[NSMutableAttributedString alloc] initWithString:nameStr];
    //蓝V
    if (user.userVerifyType == WBUserVerifyTypeOrganization) {
        UIImage *blueVImage = [UIImage imageNamed:@"avatar_enterprise_vip"];
        NSAttributedString *blueVTex = [self _attachmentWithFontSize:kWBCellNameFontSize image:blueVImage shrink:NO];
        [nameText appendString:@" "];
        [nameText appendAttributedString:blueVTex];
    }
    
    //VIP
    if (user.mbrank > 0) {
        UIImage *yellowVImage = [UIImage imageNamed:[NSString stringWithFormat:@"common_icon_membership_level%d", user.mbrank]];
        
        if (!yellowVImage) {
            yellowVImage = [UIImage imageNamed:@"common_icon_membership"];
        }
        
        NSAttributedString *vipText = [self _attachmentWithFontSize:kWBCellNameFontSize image:yellowVImage shrink:NO];
        [nameText appendString:@" "];
        [nameText appendAttributedString:vipText];
    }
    
    nameText.font = [UIFont systemFontOfSize:kWBCellNameFontSize];
    nameText.color = user.mbrank > 0 ? kWBCellNameOrangeColor : kWBCellNameNormalColor;
    nameText.lineBreakMode = NSLineBreakByCharWrapping;
    
    YYTextContainer *container = [YYTextContainer containerWithSize:CGSizeMake(kWBCellNameWidth, 9999)];
    container.maximumNumberOfRows = 1;
    _nameTextLayout = [YYTextLayout layoutWithContainer:container text:nameText];
}

///布局时间和来源
- (void)_layoutSource {
    NSMutableAttributedString *sourceText = [NSMutableAttributedString new];
    
    //发布时间
    NSString *createTime = [WBStatusHelper stringWithTimelineDate:_status.createdAt];
    if (createTime.length) {
        NSMutableAttributedString *timeText = [[NSMutableAttributedString alloc] initWithString:createTime];
        [timeText appendString:@"  "];
        timeText.font = [UIFont systemFontOfSize:kWBCellSourceFontSize];
        timeText.color = kWBCellTimeNormalColor;
        [sourceText appendAttributedString:timeText];
    }
    
    /**
     来自：XXX
     (好好看看下面如何实现的。例子：//<a href="sinaweibo://customweibosource" rel="nofollow">iPhone 5siPhone 5s</a>)
     */
    //    if (_status.source.length) {
    //        static NSRegularExpression *hrefRegex, *textRegex;
    //        static dispatch_once_t onceToken;
    //        dispatch_once(&onceToken, ^{
    //            hrefRegex = [NSRegularExpression regularExpressionWithPattern:@"(?<=href=\").+(?=\" )" options:kNilOptions error:NULL];
    //            textRegex = [NSRegularExpression regularExpressionWithPattern:@"(?<=>).+(?=<)" options:kNilOptions error:NULL];
    //        });
    //        NSTextCheckingResult *hrefResult, *textResult;
    //        NSString *href = nil, *text = nil;
    //        hrefResult = [hrefRegex firstMatchInString:_status.source options:kNilOptions range:NSMakeRange(0, _status.source.length)];
    //        textResult = [textRegex firstMatchInString:_status.source options:kNilOptions range:NSMakeRange(0, _status.source.length)];
    //        
    //        if (hrefResult && textResult && hrefResult.range.location != NSNotFound && textResult.range.location != NSNotFound) {
    //            href = [_status.source substringWithRange:hrefResult.range];
    //            text = [_status.source substringWithRange:textResult.range];
    //        }
    //        
    //        if (href.length && text.length) {
    //            NSMutableAttributedString *from = [NSMutableAttributedString new];
    //            [from appendString:[NSString stringWithFormat:@"来自%@", text]];
    //            from.font = [UIFont systemFontOfSize:kWBCellSourceFontSize];
    //            from.color = kWBCellTimeNormalColor;
    //            if (_status.sourceAllowClick > 0) {
    //                NSRange range = NSMakeRange(3, text.length);
    //                [from setColor:kWBCellTextHighlightColor range:range];
    //                YYTextBackedString *backed = [YYTextBackedString stringWithString:href];
    //                [from setTextBackedString:backed range:range];
    //                
    //                YYTextBorder *border = [YYTextBorder new];
    //                border.insets = UIEdgeInsetsMake(-2, 0, -2, 0);
    //                border.fillColor = kWBCellTextHighlightBackgroundColor;
    //                border.cornerRadius = 3;
    //                YYTextHighlight *highlight = [YYTextHighlight new];
    //                if (href) highlight.userInfo = @{kWBLinkHrefName : href};
    //                [highlight setBackgroundBorder:border];
    //                [from setTextHighlight:highlight range:range];
    //            }
    //            
    //            [sourceText appendAttributedString:from];
    //        }
    //    }
    
    if (sourceText.length == 0) {
        _sourceTextLayout = nil;
    } else {
        YYTextContainer *container = [YYTextContainer containerWithSize:CGSizeMake(kWBCellNameWidth, 9999)];
        container.maximumNumberOfRows = 1;
        _sourceTextLayout = [YYTextLayout layoutWithContainer:container text:sourceText];
    }
}

///布局转发微博内容
- (void)_layoutRetweet {
    _retweetHeight = 0;
    
    [self _layoutRetweetText];
    [self _layoutRetweetPic];
    if (_retweetPicHeight == 0) {
        [self _layoutRetweetCard];
    }
    
    _retweetHeight = _retweetTextHeight;
    //图片和卡片只可能有一种
    if (_retweetPicHeight > 0) {
        _retweetHeight += _retweetPicHeight;
        _retweetHeight += kWBCellPadding;
    } else if (_retweetCardHeight > 0) {
        _retweetHeight += _retweetCardHeight;
        _retweetHeight += kWBCellPadding;
    }
}

///布局转发微博文本
- (void)_layoutRetweetText {
    _retweetHeight = 0;
    _retweetTextLayout = nil;
    NSMutableAttributedString *text = [self _textWithStatus:_status.retweetedStatus
                                                  isRetweet:YES
                                                   fontSize:kWBCellTextFontRetweetSize
                                                  textColor:kWBCellTextSubTitleColor];
    if (text.length == 0) return;
    
    WBTextLinePositionModifier *modifier = [WBTextLinePositionModifier new];
    modifier.font = [UIFont fontWithName:@"Heiti SC" size:kWBCellTextFontRetweetSize];
    modifier.paddingTop = kWBCellPaddingText;
    modifier.paddingBottom = kWBCellPaddingText;
    
    YYTextContainer *container = [YYTextContainer new];
    container.size = CGSizeMake(kWBCellContentWidth, HUGE);
    container.linePositionModifier = modifier;
    
    _retweetTextLayout = [YYTextLayout layoutWithContainer:container text:text];
    if (!_retweetTextLayout) return;
    
    _retweetTextHeight = [modifier heightForLineCount:_retweetTextLayout.lines.count];
}

///布局转发微博图片
- (void)_layoutRetweetPic {
    [self _layoutPicsWithStatus:_status.retweetedStatus isRetweet:YES];
}

///布局微博正文卡片
- (void)_layoutPics {
    [self _layoutPicsWithStatus:_status isRetweet:NO];
}

///布局图片
- (void)_layoutPicsWithStatus:(WBStatus *)status isRetweet:(BOOL)isRetweet {
    if (isRetweet) {
        _retweetPicSize = CGSizeZero;
        _retweetPicHeight = 0;
    } else {
        _picSize = CGSizeZero;
        _picHeight = 0;
    }
    
    if (status.pics.count == 0) return;
    
    CGSize picSize = CGSizeZero;
    CGFloat picHeight = 0;
    
    CGFloat len1_3 = (kWBCellContentWidth + kWBCellPaddingPic) / 3 - kWBCellPaddingPic;
    len1_3 = CGFloatPixelRound(len1_3);
    switch (status.pics.count) {
        case 1: {
            WBPicture *pic = _status.pics.firstObject;
            WBPictureMetadata *bmiddle = pic.bmiddle;
            if (pic.keepSize || bmiddle.width < 1 || bmiddle.height < 1) {
                CGFloat maxLen = kWBCellContentWidth / 2.0;
                maxLen = CGFloatPixelRound(maxLen);
                picSize = CGSizeMake(maxLen, maxLen);
                picHeight = maxLen;
            } else {
                CGFloat maxLen = len1_3 * 2 + kWBCellPaddingPic;
                if (bmiddle.width < bmiddle.height) {
                    picSize.width = (float)bmiddle.width / (float)bmiddle.height * maxLen;
                    picSize.height = maxLen;
                } else {
                    picSize.width = maxLen;
                    picSize.height = (float)bmiddle.height / (float)bmiddle.width * maxLen;
                }
                picSize = CGSizePixelRound(picSize);
                picHeight = picSize.height;
            }
        } break;
        case 2: case 3: {
            picSize = CGSizeMake(len1_3, len1_3);
            picHeight = len1_3;
        } break;
        case 4: case 5: case 6: {
            picSize = CGSizeMake(len1_3, len1_3);
            picHeight = len1_3 * 2 + kWBCellPaddingPic;
        } break;
        default: { // 7, 8, 9
            picSize = CGSizeMake(len1_3, len1_3);
            picHeight = len1_3 * 3 + kWBCellPaddingPic * 2;
        } break;
    }
    
    if (isRetweet) {
        _retweetPicSize = picSize;
        _retweetPicHeight = picHeight;
    } else {
        _picSize = picSize;
        _picHeight = picHeight;
    }
}

///布局转发微博卡片
- (void)_layoutRetweetCard {
    [self _layoutCardWithStatus:_status.retweetedStatus isRetweet:YES];
}

///布局微博卡片
- (void)_layoutCard {
    [self _layoutCardWithStatus:_status isRetweet:NO];
}

- (void)_layoutCardWithStatus:(WBStatus *)status isRetweet:(BOOL)isRetweet {
    if (isRetweet) {
        _retweetCardType = WBStatusCardTypeNone;
        _retweetCardHeight = 0;
        _retweetCardTextLayout = nil;
        _retweetCardTextRect = CGRectZero;
    } else {
        _cardType = WBStatusCardTypeNone;
        _cardHeight = 0;
        _cardTextLayout = nil;
        _cardTextRect = CGRectZero;
    }
    WBPageInfo *pageInfo = status.pageInfo;
    if (!pageInfo) return;
    
    WBStatusCardType cardType = WBStatusCardTypeNone;
    CGFloat cardHeight = 0;
    YYTextLayout *cardTextLayout = nil;
    CGRect textRect = CGRectZero;
    
    if ((pageInfo.type == 11) && [pageInfo.objectType isEqualToString:@"video"]) {
        // 视频，一个大图片，上面播放按钮
        if (pageInfo.pagePic) {
            cardType = WBStatusCardTypeVideo;
            cardHeight = (2 * kWBCellContentWidth - kWBCellPaddingPic) / 3.0;
        }
    } else {
        BOOL hasImage = pageInfo.pagePic != nil;
        BOOL hasBadge = pageInfo.typeIcon != nil;
        WBButtonLink *button = pageInfo.buttons.firstObject;
        BOOL hasButtom = button.pic && button.name;
        
        /*
         badge: 25,25 左上角 (42)
         image: 70,70 方形
         100, 70 矩形
         btn:  60,70
         
         lineheight 20
         padding 10
         */
        textRect.size.height = 70;
        if (hasImage) {
            if (hasBadge) {
                textRect.origin.x = 100;
            } else {
                textRect.origin.x = 70;
            }
        } else {
            if (hasBadge) {
                textRect.origin.x = 42;
            }
        }
        textRect.origin.x += 10; //padding
        textRect.size.width = kWBCellContentWidth - textRect.origin.x;
        if (hasButtom) textRect.size.width -= 60;
        textRect.size.width -= 10; //padding
        
        NSMutableAttributedString *text = [NSMutableAttributedString new];
        if (pageInfo.pageTitle.length) {
            NSMutableAttributedString *title = [[NSMutableAttributedString alloc] initWithString:pageInfo.pageTitle];
            
            title.font = [UIFont systemFontOfSize:kWBCellCardTitleFontSize];
            title.color = kWBCellNameNormalColor;
            [text appendAttributedString:title];
        }
        
        if (pageInfo.pageDesc.length) {
            if (text.length) [text appendString:@"\n"];
            NSMutableAttributedString *desc = [[NSMutableAttributedString alloc] initWithString:pageInfo.pageDesc];
            desc.font = [UIFont systemFontOfSize:kWBCellCardDescFontSize];
            desc.color = kWBCellNameNormalColor;
            [text appendAttributedString:desc];
        } else if (pageInfo.content2.length) {
            if (text.length) [text appendString:@"\n"];
            NSMutableAttributedString *content3 = [[NSMutableAttributedString alloc] initWithString:pageInfo.content2];
            content3.font = [UIFont systemFontOfSize:kWBCellCardDescFontSize];
            content3.color = kWBCellTextSubTitleColor;
            [text appendAttributedString:content3];
        } else if (pageInfo.content3.length) {
            if (text.length) [text appendString:@"\n"];
            NSMutableAttributedString *content3 = [[NSMutableAttributedString alloc] initWithString:pageInfo.content3];
            content3.font = [UIFont systemFontOfSize:kWBCellCardDescFontSize];
            content3.color = kWBCellTextSubTitleColor;
            [text appendAttributedString:content3];
        }
        
        if (pageInfo.tips.length) {
            if (text.length) [text appendString:@"\n"];
            NSMutableAttributedString *tips = [[NSMutableAttributedString alloc] initWithString:pageInfo.tips];
            tips.font = [UIFont systemFontOfSize:kWBCellCardDescFontSize];
            tips.color = kWBCellTextSubTitleColor;
            [text appendAttributedString:tips];
        }
        
        if (text.length) {
            text.maximumLineHeight = 20;
            text.minimumLineHeight = 20;
            text.lineBreakMode = NSLineBreakByTruncatingTail;
            
            YYTextContainer *container = [YYTextContainer containerWithSize:textRect.size];
            container.maximumNumberOfRows = 3;
            cardTextLayout = [YYTextLayout layoutWithContainer:container text:text];
        }
        
        if (cardTextLayout) {
            cardType = WBStatusCardTypeNormal;
            cardHeight = 70;
        }
    }
    
    if (isRetweet) {
        _retweetCardType = cardType;
        _retweetCardHeight = cardHeight;
        _retweetCardTextLayout = cardTextLayout;
        _retweetCardTextRect = textRect;
    } else {
        _cardType = cardType;
        _cardHeight = cardHeight;
        _cardTextLayout = cardTextLayout;
        _cardTextRect = textRect;
    }
}

///布局微博正文
- (void)_layoutText {
    _textHeight = 0;
    _textLayout = nil;
    
    NSMutableAttributedString *text = [self _textWithStatus:_status
                                                  isRetweet:NO
                                                   fontSize:kWBCellTextFontSize
                                                  textColor:kWBCellTextNormalColor];
    if (text.length == 0) return;
    
    WBTextLinePositionModifier *modifier = [WBTextLinePositionModifier new];
    modifier.font = [UIFont fontWithName:@"Heiti SC" size:kWBCellTextFontSize];
    modifier.paddingTop = kWBCellPaddingText;
    modifier.paddingBottom = kWBCellPaddingText;
    
    YYTextContainer *container = [YYTextContainer new];
    container.size = CGSizeMake(kWBCellContentWidth, HUGE);
    container.linePositionModifier = modifier;
    
    _textLayout = [YYTextLayout layoutWithContainer:container text:text];
    if (!_textLayout) return;
    
    _textHeight = [modifier heightForLineCount:_textLayout.rowCount];
}

///布局微博标签
- (void)_layoutTag {
    _tagType = WBStatusTagTypeNone;
    _tagHeight = 0;
    
    WBTag *tag = _status.tagStruct.firstObject;
    if (tag.tagName.length == 0) return;
    
    NSMutableAttributedString *text = [[NSMutableAttributedString alloc] initWithString:tag.tagName];
    if (tag.tagType == 1) {
        _tagType = WBStatusTagTypePlace;
        _tagHeight = 40;
        text.color = [UIColor colorWithWhite:0.217 alpha:1.000];
    } else {
        _tagType = WBStatusTagTypeNormal;
        _tagHeight = 32;
        if (tag.urlTypePic) {
            NSAttributedString *pic = [self _attachmentWithFontSize:kWBCellCardDescFontSize imageURL:tag.urlTypePic.absoluteString shrink:YES];
            [text insertAttributedString:pic atIndex:0];
        }
        
        //高亮状态的背景
        YYTextBorder *highlightBorder = [YYTextBorder new];
        highlightBorder.insets = UIEdgeInsetsMake(-2, 0, -2, 0);
        highlightBorder.cornerRadius = 2;
        highlightBorder.fillColor = kWBCellTextHighlightBackgroundColor;
        
        [text setColor:kWBCellTextHighlightColor range:text.rangeOfAll];
        
        //高亮状态
        YYTextHighlight *highlight = [YYTextHighlight new];
        [highlight setBackgroundBorder:highlightBorder];
        // 数据信息，用于稍后用户点击
        highlight.userInfo = @{kWBLinkTagName : tag};
        [text setTextHighlight:highlight range:text.rangeOfAll];
    }
    text.font = [UIFont systemFontOfSize:kWBCellCardDescFontSize];
    
    YYTextContainer *container = [YYTextContainer containerWithSize:CGSizeMake(9999, 9999)];
    _tagTextLayout = [YYTextLayout layoutWithContainer:container text:text];
    if (!_tagTextLayout) {
        _tagType = WBStatusTagTypeNone;
        _tagHeight = 0;
    }
}

///布局toolbar
- (void)_layoutToolBar {
    UIFont *font = [UIFont systemFontOfSize:kWBCellToolbarFontSize];
    YYTextContainer *container = [YYTextContainer containerWithSize:CGSizeMake(kScreenWidth, kWBCellToolbarHeight)];
    container.maximumNumberOfRows = 1;
    
    //转发(发现还是很多地方用到NSMutableAttributedString类的)
    NSMutableAttributedString *repostText = [[NSMutableAttributedString alloc] initWithString:_status.repostsCount <= 0 ? @"转发" : [WBStatusHelper shortedNumberDesc:_status.repostsCount]];
    repostText.font = font;
    repostText.color = kWBCellToolbarTitleColor;
    _toolbarRepostTextLayout = [YYTextLayout layoutWithContainer:container text:repostText];
    _toolbarRepostTextWidth = CGFloatPixelRound(_toolbarRepostTextLayout.textBoundingRect.size.width);
    
    //评论
    NSMutableAttributedString *commentText = [[NSMutableAttributedString alloc] initWithString:_status.commentsCount <= 0 ? @"评论" : [WBStatusHelper shortedNumberDesc:_status.commentsCount]];
    commentText.font = font;
    commentText.color = kWBCellToolbarTitleColor;
    _toolbarCommentTextLayout = [YYTextLayout layoutWithContainer:container text:commentText];
    _toolbarCommentTextWidth = CGFloatPixelRound(_toolbarCommentTextLayout.textBoundingRect.size.width);
    
    //点赞
    NSMutableAttributedString *likeText = [[NSMutableAttributedString alloc] initWithString:_status.attitudesCount <= 0 ? @"赞" : [WBStatusHelper shortedNumberDesc:_status.attitudesCount]];
    likeText.font = font;
    likeText.color = _status.attitudesStatus ? kWBCellToolbarTitleHighlightColor : kWBCellToolbarTitleColor;
    _toolbarLikeTextLayout = [YYTextLayout layoutWithContainer:container text:likeText];
    _toolbarLikeTextWidth = CGFloatPixelRound(_toolbarLikeTextLayout.textBoundingRect.size.width);
}

#pragma mark - Help 
- (NSMutableAttributedString *)_textWithStatus:(WBStatus *)status
                                     isRetweet:(BOOL)isRetweet
                                      fontSize:(CGFloat)fontSize
                                     textColor:(UIColor *)textColor {
    if (!status) return nil;
    
    NSMutableString *string = status.text.mutableCopy;
    if (string.length == 0) return nil;
    if (isRetweet) {
        NSString *name = status.user.name;
        if (name.length == 0) {
            name = status.user.screenName;
        }
        if (name) {
            NSString *insert = [NSString stringWithFormat:@"@%@:",name];
            [string insertString:insert atIndex:0];
        }
    }
    //字体
    UIFont *font = [UIFont systemFontOfSize:fontSize];
    //高亮状态的背景
    YYTextBorder *highlightBorder = [YYTextBorder new];
    highlightBorder.insets = UIEdgeInsetsMake(-2, 0, -2, 0);
    highlightBorder.cornerRadius = 3;
    highlightBorder.fillColor = kWBCellTextHighlightBackgroundColor;
    
    NSMutableAttributedString *text = [[NSMutableAttributedString alloc] initWithString:string];
    text.font = font;
    text.color = textColor;
    
    /**
     匹配链接，文本中有链接要这个链接替换成图标+友好描述的形式。当然这个不同于独立发的图片。
     根据urlStruct 中每个 URL.shortURL 来匹配文本，将其替换为图标+友好描述。
    */
    for (WBURL *wburl in status.urlStruct) {
        if (wburl.shortURL.length == 0) continue;
        if (wburl.urlTitle.length == 0) continue;
        NSString *urlTitle = wburl.urlTitle;
        if (urlTitle.length > 27) {
            urlTitle = [[urlTitle substringToIndex:27] stringByAppendingString:YYTextTruncationToken];
        }
        
        NSRange searchRange = NSMakeRange(0, text.string.length);
        do {
            NSRange range = [text.string rangeOfString:wburl.shortURL options:kNilOptions range:searchRange];
            if (range.location == NSNotFound) break;
            
            if (range.location + range.length == text.length) {
                if (status.pageInfo.pageID && wburl.pageID &&
                    [wburl.pageID isEqualToString:status.pageInfo.pageID]) {
                    if ((!isRetweet && !status.retweetedStatus) || isRetweet) {
                        if (status.pics.count == 0) {
                            [text replaceCharactersInRange:range withString:@""];
                            break; // cut the tail, show with card
                        }
                    }
                }
            }
            
            if ([text attribute:YYTextHighlightAttributeName atIndex:range.location] == nil) {
                //替换的内容
                NSMutableAttributedString *replace = [[NSMutableAttributedString alloc] initWithString:urlTitle];
                if (wburl.urlTypePic.length) {
                    //链接头部有个图片附件 (要从网络获取)
                    NSURL *picURL = [WBStatusHelper defaultURLForImageURL:wburl.urlTypePic];
                    UIImage *image = [[YYImageCache sharedCache] getImageForKey:picURL.absoluteString];
                    NSAttributedString *pic = (image && !wburl.pics.count) ? [self _attachmentWithFontSize:fontSize image:image shrink:YES] : [self _attachmentWithFontSize:fontSize imageURL:wburl.urlTypePic shrink:YES];
                    [replace insertAttributedString:pic atIndex:0];
                }
                replace.font = font;
                replace.color = kWBCellTextHighlightColor;
                
                //高亮状态
                YYTextHighlight *highlight = [YYTextHighlight new];
                [highlight setBackgroundBorder:highlightBorder];
                //数据信息，用于稍后用户点击
                highlight.userInfo = @{kWBLinkURLName : wburl};
                [replace setTextHighlight:highlight range:NSMakeRange(0, replace.length)];
                
                //添加被替换的原始字符串，用于复制
                YYTextBackedString *backed = [YYTextBackedString stringWithString:[text.string substringWithRange:range]];
                [replace setTextBackedString:backed range:NSMakeRange(0, replace.length)];
                
                //替换
                [text replaceCharactersInRange:range withAttributedString:replace];
                
                searchRange.location = searchRange.location + (replace.length ? replace.length : 1);
                if (searchRange.location + 1 >= text.length) break;
                searchRange.length = text.length - searchRange.location;
            } else {
                searchRange.location = searchRange.location + (searchRange.length ? searchRange.length : 1);
                if (searchRange.location + 1>= text.length) break;
                searchRange.length = text.length - searchRange.location;
            }
        } while (1);
    }
    
    /**
     匹配#话题# 根据topicStruct 中每个 Topic.topicTitle 来匹配文本，标记为话题
     */
    if (status.topicStruct) {
        for (WBTopic *topic in status.topicStruct) {
            if (topic.topicTitle.length == 0) continue;
            NSString *topicTitle = [NSString stringWithFormat:@"#%@#", topic.topicTitle];
            NSRange searchRange = NSMakeRange(0, text.string.length);
            do {
                NSRange range = [text.string rangeOfString:topicTitle options:kNilOptions range:searchRange];
                if (range.location == NSNotFound) break;
                
                if ([text attribute:YYTextHighlightAttributeName atIndex:range.location] == nil) {
                    [text setColor:kWBCellTextHighlightColor range:range];
                    
                    //高亮状态
                    YYTextHighlight *highlight = [YYTextHighlight new];
                    [highlight setBackgroundBorder:highlightBorder];
                    //数据信息，用于稍后用户点击
                    highlight.userInfo = @{kWBLinkTopicName : topic};
                    [text setTextHighlight:highlight range:range];
                }
                searchRange.location = searchRange.location + (searchRange.length ? searchRange.length : 1);
                if (searchRange.location + 1>= text.length) break;
                searchRange.length = text.length - searchRange.location;
            } while (1);
        }
    } else {
        
    }
    
    /**
     匹配 @用户名
     */
    NSArray *atResults = [[WBStatusHelper regexAt] matchesInString:text.string options:kNilOptions range:text.rangeOfAll];
    for (NSTextCheckingResult *at in atResults) {
        if (at.range.location == NSNotFound && at.range.length <= 1) continue;
        if ([text attribute:YYTextHighlightAttributeName atIndex:at.range.location] == nil) {
            [text setColor:kWBCellTextHighlightColor range:at.range];
            
            //高亮状态
            YYTextHighlight *highlight = [YYTextHighlight new];
            [highlight setBackgroundBorder:highlightBorder];
            //数据信息，用于稍后用户点击
            highlight.userInfo = @{kWBLinkAtName : [text.string substringWithRange:NSMakeRange(at.range.location + 1, at.range.length - 1)]};
            [text setTextHighlight:highlight range:at.range];
        }
    }
    
    /**
     匹配 [表情]
     */
    NSArray *emoticonResults = [[WBStatusHelper regexEmoticon] matchesInString:text.string options:kNilOptions range:text.rangeOfAll];
    NSUInteger emoClipLength = 0;
    for (NSTextCheckingResult *emo in emoticonResults) {
        if (emo.range.location == NSNotFound && emo.range.length <= 1) continue;
        NSRange range = emo.range;
        range.location -= emoClipLength;
        if ([text attribute:YYTextHighlightAttributeName atIndex:range.location]) continue;
        if ([text attribute:YYTextAttachmentAttributeName atIndex:range.location]) continue;
        NSString *emoString = [text.string substringWithRange:range];
        NSString *imagePath = [WBStatusHelper emoticonDic][emoString];
        UIImage *image = [WBStatusHelper imageWithPath:imagePath];
        if (!image) continue;
        
        //替换原本的[表情]文本
        NSAttributedString *emoText = [NSAttributedString attachmentStringWithEmojiImage:image fontSize:fontSize];
        [text replaceCharactersInRange:range withAttributedString:emoText];
        emoClipLength += range.length - 1;
    }
    
    return text;
}

- (NSAttributedString *)_attachmentWithFontSize:(CGFloat)fontSize image:(UIImage *)image shrink:(BOOL)shrink {
    //Heiti SC 字体
    CGFloat ascent = fontSize * 0.86;
    CGFloat descent = fontSize * 0.14;
    CGRect bounding = CGRectMake(0, -0.14 * fontSize, fontSize, fontSize);
    UIEdgeInsets contentInsets = UIEdgeInsetsMake(ascent - (bounding.size.height + bounding.origin.y), 0, descent + bounding.origin.y, 0);
    
    YYTextRunDelegate *delegate = [YYTextRunDelegate new];
    delegate.ascent = ascent;
    delegate.descent = descent;
    delegate.width = bounding.size.width;
    
    YYTextAttachment *attachment = [YYTextAttachment new];
    attachment.contentMode = UIViewContentModeScaleAspectFit;
    attachment.contentInsets = contentInsets;
    attachment.content = image;
    
    if (shrink) {
        //缩小~
        CGFloat scale = 1 / 10.0;
        contentInsets.top += fontSize * scale;
        contentInsets.bottom += fontSize * scale;
        contentInsets.left += fontSize * scale;
        contentInsets.right += fontSize * scale;
        contentInsets = UIEdgeInsetPixelFloor(contentInsets);
        attachment.contentInsets = contentInsets;
    }
    
    NSMutableAttributedString *atr = [[NSMutableAttributedString alloc] initWithString:YYTextAttachmentToken];
    [atr setTextAttachment:attachment range:NSMakeRange(0, atr.length)];
    CTRunDelegateRef ctDelegate = delegate.CTRunDelegate;
    [atr setRunDelegate:ctDelegate range:NSMakeRange(0, atr.length)];
    if (ctDelegate) CFRelease(ctDelegate);
    
    return atr;
}

- (NSAttributedString *)_attachmentWithFontSize:(CGFloat)fontSize imageURL:(NSString *)imageURL shrink:(BOOL)shrink {
    /*
     微博 URL 嵌入的图片，比临近的字体要小一圈。。
     这里模拟一下 Heiti SC 字体，然后把图片缩小一下。
     */
    CGFloat ascent = fontSize * 0.86;
    CGFloat descent = fontSize * 0.14;
    CGRect bounding = CGRectMake(0, -0.14 * fontSize, fontSize, fontSize);
    UIEdgeInsets contentInsets = UIEdgeInsetsMake(ascent - (bounding.size.height + bounding.origin.y), 0, descent + bounding.origin.y, 0);
    CGSize size = CGSizeMake(fontSize, fontSize);
    
    if (shrink) {
        //缩小~
        CGFloat scale = 1 / 10.0;
        contentInsets.top += fontSize * scale;
        contentInsets.bottom += fontSize * scale;
        contentInsets.left += fontSize * scale;
        contentInsets.right += fontSize * scale;
        contentInsets = UIEdgeInsetPixelFloor(contentInsets);
        size = CGSizeMake(fontSize - fontSize * scale * 2, fontSize - fontSize * scale * 2);
        size = CGSizePixelRound(size);
    }
    
    YYTextRunDelegate *delegate = [YYTextRunDelegate new];
    delegate.ascent = ascent;
    delegate.descent = descent;
    delegate.width = bounding.size.width;
    
    WBTextImageViewAttachment *attachment = [WBTextImageViewAttachment new];
    attachment.contentMode = UIViewContentModeScaleAspectFit;
    attachment.contentInsets = contentInsets;
    attachment.size = size;
    attachment.imageURL = [WBStatusHelper defaultURLForImageURL:imageURL];
    
    NSMutableAttributedString *atr = [[NSMutableAttributedString alloc] initWithString:YYTextAttachmentToken];
    [atr setTextAttachment:attachment range:NSMakeRange(0, atr.length)];
    CTRunDelegateRef ctDelegate = delegate.CTRunDelegate;
    [atr setRunDelegate:ctDelegate range:NSMakeRange(0, atr.length)];
    if (ctDelegate) CFRelease(ctDelegate);
    
    return atr;
}

@end

