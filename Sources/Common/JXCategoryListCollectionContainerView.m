//
//  JXCategoryListCollectionContainerView.m
//  JXCategoryView
//
//  Created by jiaxin on 2018/9/12.
//  Copyright © 2018年 jiaxin. All rights reserved.
//

#import "JXCategoryListCollectionContainerView.h"

@interface JXCategoryListCollectionContainerView () <UICollectionViewDelegate, UICollectionViewDataSource>
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, assign) NSInteger currentIndex;
@property (nonatomic, strong) NSMutableDictionary <NSNumber *, id<JXCategoryListCollectionContentViewDelegate>> *validListDict;
@property (nonatomic, strong) NSLock *lock;
@property (nonatomic, assign) BOOL willRemoveFromWindow;
@property (nonatomic, assign) BOOL isFirstMoveToWindow;
@end

@implementation JXCategoryListCollectionContainerView

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveMemoryWarningNotification:) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
        _isFirstMoveToWindow = YES;
        _validListDict = [NSMutableDictionary dictionary];
        _lock = [[NSLock alloc] init];
        [self initializeViews];
    }
    return self;
}

- (void)willMoveToWindow:(UIWindow *)newWindow {
    if (self.isFirstMoveToWindow) {
        //第一次调用过滤，因为第一次列表显示通知会从willDisplayCell方法通知
        self.isFirstMoveToWindow = NO;
        return;
    }
    //当前页面push到一个新的页面时，willMoveToWindow会调用三次。第一次调用的newWindow为nil，第二次调用间隔1ms左右newWindow有值，第三次调用间隔400ms左右newWindow为nil。
    //根据上述事实，第一次和第二次为无效调用，可以根据其间隔1ms左右过滤掉
    if (newWindow == nil) {
        self.willRemoveFromWindow = YES;
        [self performSelector:@selector(currentListDidDisappear) withObject:nil afterDelay:0.02];
    }else {
        if (self.willRemoveFromWindow) {
            self.willRemoveFromWindow = NO;
            [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(currentListDidDisappear) object:nil];
        }else {
            [self currentListDidAppear];
        }
    }
}

- (void)initializeViews {
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    layout.minimumLineSpacing = 0;
    layout.minimumInteritemSpacing = 0;
    if (self.dataSource &&
        [self.dataSource respondsToSelector:@selector(collectionViewClassInListContainerView:)] &&
        [[self.dataSource collectionViewClassInListContainerView:self] isKindOfClass:[UICollectionView class]]) {
        _collectionView = (UICollectionView *)[[[self.dataSource collectionViewClassInListContainerView:self] alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    }else {
        _collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    }
    self.collectionView.pagingEnabled = YES;
    self.collectionView.showsHorizontalScrollIndicator = NO;
    self.collectionView.showsVerticalScrollIndicator = NO;
    self.collectionView.scrollsToTop = NO;
    self.collectionView.bounces = NO;
    self.collectionView.dataSource = self;
    self.collectionView.delegate = self;
    [self.collectionView registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:@"cell"];
    if (@available(iOS 10.0, *)) {
        self.collectionView.prefetchingEnabled = NO;
    }
    if (@available(iOS 11.0, *)) {
        self.collectionView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    }
    [self addSubview:self.collectionView];
}

- (void)reloadData {
    [_lock lock];
    for (id<JXCategoryListCollectionContentViewDelegate> list in _validListDict.allValues) {
        [[list listView] removeFromSuperview];
    }
    [_validListDict removeAllObjects];
    [_lock unlock];

    [self.collectionView reloadData];
}

- (void)layoutSubviews {
    [super layoutSubviews];

    self.collectionView.frame = self.bounds;
}

#pragma mark - Private

- (void)currentListDidAppear {
    [self listDidAppear:self.currentIndex];
}

- (void)currentListDidDisappear {
    self.willRemoveFromWindow = NO;
    [self listDidDisappear:self.currentIndex];
}

- (void)listDidAppear:(NSInteger)index {
    NSUInteger count = 0;
    if (self.dataSource && [self.dataSource respondsToSelector:@selector(numberOfListsInlistContainerView:)]) {
        count = [self.dataSource numberOfListsInlistContainerView:self];
    }
    if (count <= 0 || index >= count) {
        return;
    }
    self.currentIndex = index;

    [_lock lock];
    id<JXCategoryListCollectionContentViewDelegate> list = _validListDict[@(index)];
    [_lock unlock];
    if (list && [list respondsToSelector:@selector(listDidAppear)]) {
        [list listDidAppear];
    }
}

- (void)listDidDisappear:(NSInteger)index {
    NSUInteger count = 0;
    if (self.dataSource && [self.dataSource respondsToSelector:@selector(numberOfListsInlistContainerView:)]) {
        count = [self.dataSource numberOfListsInlistContainerView:self];
    }
    if (count <= 0 || index >= count) {
        return;
    }
    [_lock lock];
    id<JXCategoryListCollectionContentViewDelegate> list = _validListDict[@(index)];
    [_lock unlock];
    if (list && [list respondsToSelector:@selector(listDidDisappear)]) {
        [list listDidDisappear];
    }
}

- (void)didReceiveMemoryWarningNotification:(NSNotification *)notification {
    [_lock lock];
    id<JXCategoryListCollectionContentViewDelegate> currentList = _validListDict[@(_currentIndex)];
    [_validListDict removeAllObjects];
    [_validListDict setObject:currentList forKey:@(_currentIndex)];
    [_lock unlock];
}

#pragma mark - UICollectionViewDelegate, UICollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    NSUInteger count = 0;
    if (self.dataSource && [self.dataSource respondsToSelector:@selector(numberOfListsInlistContainerView:)]) {
        count = [self.dataSource numberOfListsInlistContainerView:self];
    }
    return count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"cell" forIndexPath:indexPath];
    for (UIView *subview in cell.contentView.subviews) {
        [subview removeFromSuperview];
    }
    self.currentIndex = indexPath.item;
    [_lock lock];
    id<JXCategoryListCollectionContentViewDelegate> list = _validListDict[@(indexPath.item)];
    if (list == nil && self.dataSource && [self.dataSource respondsToSelector:@selector(listContainerView:initListForIndex:)]) {
        list = [self.dataSource listContainerView:self initListForIndex:indexPath.item];
        if (list != nil) {
            _validListDict[@(indexPath.item)] = list;
        }
    }
    [_lock unlock];
    if (list != nil) {
        [list listView].frame = cell.contentView.bounds;
        [cell.contentView addSubview:[list listView]];
    }
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView willDisplayCell:(UICollectionViewCell *)cell forItemAtIndexPath:(NSIndexPath *)indexPath {
    id<JXCategoryListCollectionContentViewDelegate> list = _validListDict[@(indexPath.item)];
    if (list && [list respondsToSelector:@selector(listDidAppear)]) {
        [list listDidAppear];
    }
}

- (void)collectionView:(UICollectionView *)collectionView didEndDisplayingCell:(UICollectionViewCell *)cell forItemAtIndexPath:(NSIndexPath *)indexPath {
    id<JXCategoryListCollectionContentViewDelegate> list = _validListDict[@(indexPath.item)];
    if (list && [list respondsToSelector:@selector(listDidAppear)]) {
        [list listDidDisappear];
    }
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    return self.bounds.size;
}

@end