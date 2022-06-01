//
//  BannerView.swift
//  SwiftBannerView
//
//  Created by iOS on 2020/8/26.
//

import UIKit

public protocol PageViewDataSource: AnyObject{
    
    /// 代理:设置page个数
    /// - Parameter pageView: pageView
    func numberOfItems(in pageView: PageView) -> Int
    
    /// 代理: 返回注册的page Cell
    /// - Parameters:
    ///   - pageView: pageView
    ///   - indexPath: indexPath
    func pageView(_ pageView: PageView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell

}

@objc public protocol  PageViewDelegate {
    
    /// 代理: 返回点击page的序号
    /// - Parameters:
    ///   - pageView: pageView
    ///   - index: index
    @objc optional func pageView(_ pageView: PageView, didSelectItemAt index: Int)
    
    /// 代理: 即将滑动到第几个page
    /// - Parameters:
    ///   - pageView: pageView
    ///   - index: index
    @objc optional func pageView(_ pageView: PageView, willScrollToItemAt index: Int)
    
    /// 代理 已经滑动到的page 序号
    /// - Parameters:
    ///   - pageView: pageView
    ///   - index: index
    @objc optional func pageView(_ pageView: PageView, didScrollToItemAt index: Int)
    
    /// 代理: pageView即将拖动
    /// - Parameter pageView: pageView
    @objc optional func pageViewWillBeginDragging(_ pageView: PageView)
    
    /// 代理: page拖动即将结束
    /// - Parameters:
    ///   - pageView: pageView
    ///   - targetIndex: targetIndex
    @objc optional func pageViewWillEndDragging(_ pageView: PageView, targetIndex: Int)
    
    /// 代理: page滑动代理
    /// - Parameters:
    ///   - pageView: pageView
    ///   - scrollProgress: 滑动百分比
    @objc optional func pageViewDidScroll(_ pageView: PageView, scrollProgress: CGFloat)

    @objc optional func pageViewDidEndScrollAnimation(_ pageView: PageView)

    @objc optional func pageViewDidEndDecelerating(_ pageView: PageView)
    
}

extension PageView{
    
    /// pagecell复用
    /// - Parameters:
    ///   - cellType: cell的类
    ///   - indexPath: indexPath
    /// - Returns: cell
    public func dequeueReusableCell<T: UICollectionViewCell>(_ cellType: T.Type = T.self, indexPath: IndexPath) -> T {
        let bareCell = collectionView.dequeueReusableCell(withReuseIdentifier: "\(cellType.self)", for: indexPath)
            guard let cell = bareCell as? T else {
                fatalError(
                    "Failed to dequeue a cell with \(cellType.self). "
                )
            }
        return cell
    }
    
    /// 注册pageCell
    /// - Parameter cellType: cell类
    public func registerCell<T: UICollectionViewCell>(_ cellType: T.Type = T.self) {
        collectionView.register(cellType.self, forCellWithReuseIdentifier: "\(cellType.self)")
    }
}

public class PageView: UIView {

    public weak var delegate: PageViewDelegate?
    public weak var dataSource: PageViewDataSource?
    
    public enum ScrollDirection: Int {
        case horizontal
        case vertical
    }
    /// 滚动方向
    public var scrollDirection: ScrollDirection = .horizontal {
        didSet {
            flowLayout.forceInvalidate()
        }
    }
    
    /// 自动滚动时间间隔
    public var automaticSlidingInterval: CGFloat = 0.0 {
        didSet {
            cancelTimer()
            if automaticSlidingInterval > 0 {
                startTimer()
            }
        }
    }
    
    /// 间距
    public var interitemSpacing: CGFloat = 0 {
        didSet {
            flowLayout.forceInvalidate()
        }
    }
    
    /// cell大小
    public var itemSize: CGSize = automaticSize {
        didSet {
            flowLayout.forceInvalidate()
        }
    }
    
    /// 是否无限滚动
    public var isInfinite: Bool = true {
        didSet {
            flowLayout.needsReprepare = true
            collectionView.reloadData()
        }
    }
    
    public static let automaticDistance: UInt = 0
    public var decelerationDistance: UInt = 1
    public static let automaticSize: CGSize = .zero
    
    public var isScrollEnabled: Bool {
        set { collectionView.isScrollEnabled = newValue }
        get { return collectionView.isScrollEnabled }
    }
    
    public var bounces: Bool {
        set { collectionView.bounces = newValue }
        get { return collectionView.bounces }
    }
    
    public var alwaysBounceHorizontal: Bool {
        set { collectionView.alwaysBounceHorizontal = newValue }
        get { return collectionView.alwaysBounceHorizontal }
    }
    
    public var alwaysBounceVertical: Bool {
        set { collectionView.alwaysBounceVertical = newValue }
        get { return collectionView.alwaysBounceVertical }
    }
    
    public var removesInfiniteLoopForSingleItem: Bool = false {
        didSet {
            reloadData()
        }
    }
    
    public var backgroundView: UIView? {
        didSet {
            if let backgroundView = backgroundView {
                if backgroundView.superview != nil {
                    backgroundView.removeFromSuperview()
                }
                insertSubview(backgroundView, at: 0)
                setNeedsLayout()
            }
        }
    }
    
    public var transformer: Transformer? {
        didSet {
            transformer?.pagerView = self
            flowLayout.forceInvalidate()
        }
    }
    
    public var isTracking: Bool {
        return collectionView.isTracking
    }
    
    public var scrollOffset: CGFloat {
        let contentOffset = max(collectionView.contentOffset.x, collectionView.contentOffset.y)
        let scrollOffset = Double(contentOffset/flowLayout.itemSpacing)
        return fmod(CGFloat(scrollOffset), CGFloat(numberOfItems))
    }
    
    public var panGestureRecognizer: UIPanGestureRecognizer {
        return collectionView.panGestureRecognizer
    }
    
    @objc public fileprivate(set) dynamic var currentIndex: Int = 0
    
    lazy var flowLayout: Layout = {
        let flowLayout = Layout()
        return flowLayout
    }()
    
    lazy var collectionView: UICollectionView = {
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: flowLayout)
        collectionView.isPagingEnabled = false
        collectionView.showsVerticalScrollIndicator = false
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.scrollsToTop = false
        collectionView.backgroundColor = UIColor.clear
        collectionView.bounces = false
        collectionView.decelerationRate = UIScrollView.DecelerationRate.fast
        collectionView.contentInset = .zero
        collectionView.scrollsToTop = false
        if #available(iOS 10.0, *) {
            collectionView.isPrefetchingEnabled = false
        }
        if #available(iOS 11.0, *) {
            collectionView.contentInsetAdjustmentBehavior = .never
        }
        return collectionView
    }()

    
    internal var timer: Timer?
    internal var numberOfItems: Int = 0
    internal var numberOfSections: Int = 0
    fileprivate var dequeingSection = 0
    
    fileprivate var centermostIndexPath: IndexPath {
        guard numberOfItems > 0, collectionView.contentSize != .zero else {
            return IndexPath(item: 0, section: 0)
        }
        let sortedIndexPaths = collectionView.indexPathsForVisibleItems.sorted { (l, r) -> Bool in
            let leftFrame = flowLayout.frame(for: l)
            let rightFrame = flowLayout.frame(for: r)
            var leftCenter: CGFloat,rightCenter: CGFloat,ruler: CGFloat
            switch scrollDirection {
            case .horizontal:
                leftCenter = leftFrame.midX
                rightCenter = rightFrame.midX
                ruler = collectionView.bounds.midX
            case .vertical:
                leftCenter = leftFrame.midY
                rightCenter = rightFrame.midY
                ruler = collectionView.bounds.midY
            }
            return abs(ruler-leftCenter) < abs(ruler-rightCenter)
        }
        let indexPath = sortedIndexPaths.first
        if let indexPath = indexPath {
            return indexPath
        }
        return IndexPath(item: 0, section: 0)
    }
    
    fileprivate var isPossiblyRotating: Bool {
        guard let animationKeys = layer.animationKeys() else {
            return false
        }
        let rotationAnimationKeys = ["position", "bounds.origin", "bounds.size"]
        return animationKeys.contains(where: { rotationAnimationKeys.contains($0) })
    }
    
    fileprivate var possibleTargetingIndexPath: IndexPath?
    
    public override init(frame: CGRect) {
        super.init(frame: frame)

        addSubview(collectionView)
        collectionView.register(PageCell.self, forCellWithReuseIdentifier: "\(PageCell.self)")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        collectionView.frame = bounds
    }
    
    override public func willMove(toWindow newWindow: UIWindow?) {
        super.willMove(toWindow: newWindow)
        if newWindow != nil {
            startTimer()
        } else {
            cancelTimer()
        }
    }
    
    public func reloadData() {
        flowLayout.needsReprepare = true;
        collectionView.reloadData()
    }
    
    deinit {
        collectionView.delegate = nil
        collectionView.dataSource = nil
    }
    
}

extension PageView: UICollectionViewDelegate,UICollectionViewDataSource{

    public func numberOfSections(in collectionView: UICollectionView) -> Int {
        guard let dataSource = dataSource else {
            return 1
        }
        numberOfItems = dataSource.numberOfItems(in: self)
        guard numberOfItems > 0 else {
            return 0;
        }
        numberOfSections = isInfinite && (numberOfItems > 1 || !removesInfiniteLoopForSingleItem) ? Int(Int16.max)/numberOfItems : 1
        return numberOfSections
    }
    
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return numberOfItems
    }
    
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        dequeingSection = indexPath.section
        let cell = dataSource!.pageView(self, cellForItemAt: indexPath)
        return cell
    }
    
    // MARK: - UICollectionViewDelegate
    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: false)
        guard let function = delegate?.pageView(_:didSelectItemAt:) else {
            return
        }
        possibleTargetingIndexPath = indexPath
        defer {
            possibleTargetingIndexPath = nil
        }
        let index = indexPath.item % numberOfItems
        function(self,index)
    }

    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if !isPossiblyRotating && numberOfItems > 0 {
            // In case someone is using KVO
            if let function = delegate?.pageView(_:willScrollToItemAt:){
                let currentIdx = lround(Double(scrollOffset)) % numberOfItems
                if (currentIndex != currentIdx) {
                    currentIndex = currentIdx
                }
                function(self,currentIndex)
            }
        }
        
        if let function = delegate?.pageViewDidScroll  {
            function(self, scrollOffset)
        }
        
    }
    
    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        if let function = delegate?.pageViewWillBeginDragging(_:) {
            function(self)
        }
        if automaticSlidingInterval > 0 {
            cancelTimer()
        }
    }
    
    public func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        if let function = delegate?.pageViewWillEndDragging(_:targetIndex:) {
            let contentOffset = scrollDirection == .horizontal ? targetContentOffset.pointee.x : targetContentOffset.pointee.y
            let targetItem = lround(Double(contentOffset/flowLayout.itemSpacing))
            function(self, targetItem % numberOfItems)
        }
        if automaticSlidingInterval > 0 {
            startTimer()
        }
    }
     
    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        if let function = delegate?.pageViewDidEndDecelerating {
            function(self)
        }
        if let function = delegate?.pageView(_:didScrollToItemAt:){
            let currentIdx = lround(Double(scrollOffset)) % numberOfItems
            if (currentIndex != currentIdx) {
                currentIndex = currentIdx
            }
            function(self,currentIndex)
        }
    }
    
    public func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        
        if let function = delegate?.pageView(_:didScrollToItemAt:){
            let currentIdx = lround(Double(scrollOffset)) % numberOfItems
            if (currentIndex != currentIdx) {
                currentIndex = currentIdx
            }
            function(self,currentIndex)
        }
        
        if let function = delegate?.pageViewDidEndScrollAnimation {
            function(self)
        }
    }
    
}

// MARK: - 定时器操作
extension PageView {
    
    fileprivate func startTimer() {
        guard automaticSlidingInterval > 0 && timer == nil else {
            return
        }
        timer = Timer.scheduledTimer(timeInterval: TimeInterval(automaticSlidingInterval), target: self, selector: #selector(flipNext(sender:)), userInfo: nil, repeats: true)
        RunLoop.current.add(timer!, forMode: .common)
    }
    
    @objc
    fileprivate func flipNext(sender: Timer?) {
        guard let _ = superview, let _ = window, numberOfItems > 0, !isTracking else {
            return
        }
        let contentOffset: CGPoint = {
            let indexPath = centermostIndexPath
            let section = numberOfSections > 1 ? (indexPath.section+(indexPath.item+1)/numberOfItems) : 0
            let item = (indexPath.item+1) % numberOfItems
            return flowLayout.contentOffset(for: IndexPath(item: item, section: section))
        }()
        collectionView.setContentOffset(contentOffset, animated: true)
    }
    
    fileprivate func cancelTimer() {
        guard timer != nil else {
            return
        }
        timer!.invalidate()
        timer = nil
    }
    
    fileprivate func nearbyIndexPath(for index: Int) -> IndexPath {
        // Is there a better algorithm?
        let currentIdx = currentIndex
        let currentSection = centermostIndexPath.section
        if abs(currentIdx-index) <= numberOfItems/2 {
            return IndexPath(item: index, section: currentSection)
        } else if (index-currentIdx >= 0) {
            return IndexPath(item: index, section: currentSection-1)
        } else {
            return IndexPath(item: index, section: currentSection+1)
        }
    }
    
}
