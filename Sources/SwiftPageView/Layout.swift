//
//  Transformer.swift
//  SwiftBannerView
//
//  Created by iOS on 2020/8/26.
//

import UIKit

class Layout: UICollectionViewLayout {

    internal var contentSize: CGSize = .zero
    internal var leadingSpacing: CGFloat = 0
    internal var itemSpacing: CGFloat = 0
    internal var needsReprepare = true
    internal var scrollDirection: PageView.ScrollDirection = .horizontal
    
    open override class var layoutAttributesClass: AnyClass {
        return LayoutAttributes.self
    }
    
    fileprivate var pagerView: PageView? {
        return self.collectionView?.superview as? PageView
    }
    
    fileprivate var collectionViewSize: CGSize = .zero
    fileprivate var numberOfSections = 1
    fileprivate var numberOfItems = 0
    fileprivate var actualInteritemSpacing: CGFloat = 0
    fileprivate var actualItemSize: CGSize = .zero
    
    override init() {
        super.init()
        self.commonInit()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.commonInit()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: UIDevice.orientationDidChangeNotification, object: nil)
    }
    
    override open func prepare() {
        guard let collectionView = self.collectionView, let pagerView = self.pagerView else {
            return
        }
        guard self.needsReprepare || self.collectionViewSize != collectionView.frame.size else {
            return
        }
        self.needsReprepare = false
        
        self.collectionViewSize = collectionView.frame.size

        // Calculate basic parameters/variables
        self.numberOfSections = pagerView.numberOfSections(in: collectionView)
        self.numberOfItems = pagerView.collectionView(collectionView, numberOfItemsInSection: 0)
        self.actualItemSize = {
            var size = pagerView.itemSize
            if size == .zero {
                size = collectionView.frame.size
            }
            return size
        }()
        
        self.actualInteritemSpacing = {
            if let transformer = pagerView.transformer {
                return transformer.proposedInteritemSpacing()
            }
            return pagerView.interitemSpacing
        }()
        self.scrollDirection = pagerView.scrollDirection
        self.leadingSpacing = self.scrollDirection == .horizontal ? (collectionView.frame.width-self.actualItemSize.width)*0.5 : (collectionView.frame.height-self.actualItemSize.height)*0.5
        self.itemSpacing = (self.scrollDirection == .horizontal ? self.actualItemSize.width : self.actualItemSize.height) + self.actualInteritemSpacing
        
        // Calculate and cache contentSize, rather than calculating each time
        self.contentSize = {
            let numberOfItems = self.numberOfItems*self.numberOfSections
            switch self.scrollDirection {
                case .horizontal:
                    var contentSizeWidth: CGFloat = self.leadingSpacing*2 // Leading & trailing spacing
                    contentSizeWidth += CGFloat(numberOfItems-1)*self.actualInteritemSpacing // Interitem spacing
                    contentSizeWidth += CGFloat(numberOfItems)*self.actualItemSize.width // Item sizes
                    let contentSize = CGSize(width: contentSizeWidth, height: collectionView.frame.height)
                    return contentSize
                case .vertical:
                    var contentSizeHeight: CGFloat = self.leadingSpacing*2 // Leading & trailing spacing
                    contentSizeHeight += CGFloat(numberOfItems-1)*self.actualInteritemSpacing // Interitem spacing
                    contentSizeHeight += CGFloat(numberOfItems)*self.actualItemSize.height // Item sizes
                    let contentSize = CGSize(width: collectionView.frame.width, height: contentSizeHeight)
                    return contentSize
            }
        }()
        self.adjustCollectionViewBounds()
    }
    
    override open var collectionViewContentSize: CGSize {
        return self.contentSize
    }
    
    override open func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        return true
    }
    
    override open func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        var layoutAttributes = [UICollectionViewLayoutAttributes]()
        guard self.itemSpacing > 0, !rect.isEmpty else {
            return layoutAttributes
        }
        let rect = rect.intersection(CGRect(origin: .zero, size: self.contentSize))
        guard !rect.isEmpty else {
            return layoutAttributes
        }
        // Calculate start position and index of certain rects
        let numberOfItemsBefore = self.scrollDirection == .horizontal ? max(Int((rect.minX-self.leadingSpacing)/self.itemSpacing),0) : max(Int((rect.minY-self.leadingSpacing)/self.itemSpacing),0)
        let startPosition = self.leadingSpacing + CGFloat(numberOfItemsBefore)*self.itemSpacing
        let startIndex = numberOfItemsBefore
        // Create layout attributes
        var itemIndex = startIndex
        
        var origin = startPosition
        let maxPosition = self.scrollDirection == .horizontal ? min(rect.maxX,self.contentSize.width-self.actualItemSize.width-self.leadingSpacing) : min(rect.maxY,self.contentSize.height-self.actualItemSize.height-self.leadingSpacing)
        // https://stackoverflow.com/a/10335601/2398107
        while origin-maxPosition <= max(CGFloat(100.0) * .ulpOfOne * abs(origin+maxPosition), .leastNonzeroMagnitude) {
            let indexPath = IndexPath(item: itemIndex%self.numberOfItems, section: itemIndex/self.numberOfItems)
            let attributes = self.layoutAttributesForItem(at: indexPath) as! LayoutAttributes
            self.applyTransform(to: attributes, with: self.pagerView?.transformer)
            layoutAttributes.append(attributes)
            itemIndex += 1
            origin += self.itemSpacing
        }
        return layoutAttributes
        
    }
    
    override open func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        let attributes = LayoutAttributes(forCellWith: indexPath)
        attributes.indexPath = indexPath
        let frame = self.frame(for: indexPath)
        let center = CGPoint(x: frame.midX, y: frame.midY)
        attributes.center = center
        attributes.size = self.actualItemSize
        return attributes
    }
    
    override open func targetContentOffset(forProposedContentOffset proposedContentOffset: CGPoint, withScrollingVelocity velocity: CGPoint) -> CGPoint {
        guard let collectionView = self.collectionView, let pagerView = self.pagerView else {
            return proposedContentOffset
        }
        var proposedContentOffset = proposedContentOffset
        
        func calculateTargetOffset(by proposedOffset: CGFloat, boundedOffset: CGFloat) -> CGFloat {
            var targetOffset: CGFloat
            if pagerView.decelerationDistance == PageView.automaticDistance {
                if abs(velocity.x) >= 0.3 {
                    let vector: CGFloat = velocity.x >= 0 ? 1.0 : -1.0
                    targetOffset = round(proposedOffset/self.itemSpacing+0.35*vector) * self.itemSpacing // Ceil by 0.15, rather than 0.5
                } else {
                    targetOffset = round(proposedOffset/self.itemSpacing) * self.itemSpacing
                }
            } else {
                let extraDistance = max(pagerView.decelerationDistance-1, 0)
                switch velocity.x {
                case 0.3 ... CGFloat.greatestFiniteMagnitude:
                    targetOffset = ceil(collectionView.contentOffset.x/self.itemSpacing+CGFloat(extraDistance)) * self.itemSpacing
                case -CGFloat.greatestFiniteMagnitude ... -0.3:
                    targetOffset = floor(collectionView.contentOffset.x/self.itemSpacing-CGFloat(extraDistance)) * self.itemSpacing
                default:
                    targetOffset = round(proposedOffset/self.itemSpacing) * self.itemSpacing
                }
            }
            targetOffset = max(0, targetOffset)
            targetOffset = min(boundedOffset, targetOffset)
            return targetOffset
        }
        let proposedContentOffsetX: CGFloat = {
            if self.scrollDirection == .vertical {
                return proposedContentOffset.x
            }
            let boundedOffset = collectionView.contentSize.width-self.itemSpacing
            return calculateTargetOffset(by: proposedContentOffset.x, boundedOffset: boundedOffset)
        }()
        let proposedContentOffsetY: CGFloat = {
            if self.scrollDirection == .horizontal {
                return proposedContentOffset.y
            }
            let boundedOffset = collectionView.contentSize.height-self.itemSpacing
            return calculateTargetOffset(by: proposedContentOffset.y, boundedOffset: boundedOffset)
        }()
        proposedContentOffset = CGPoint(x: proposedContentOffsetX, y: proposedContentOffsetY)
        return proposedContentOffset
    }
    
    // MARK:- Internal functions
    
    internal func forceInvalidate() {
        self.needsReprepare = true
        self.invalidateLayout()
    }
    
    internal func contentOffset(for indexPath: IndexPath) -> CGPoint {
        let origin = self.frame(for: indexPath).origin
        guard let collectionView = self.collectionView else {
            return origin
        }
        let contentOffsetX: CGFloat = {
            if self.scrollDirection == .vertical {
                return 0
            }
            let contentOffsetX = origin.x - (collectionView.frame.width*0.5-self.actualItemSize.width*0.5)
            return contentOffsetX
        }()
        let contentOffsetY: CGFloat = {
            if self.scrollDirection == .horizontal {
                return 0
            }
            let contentOffsetY = origin.y - (collectionView.frame.height*0.5-self.actualItemSize.height*0.5)
            return contentOffsetY
        }()
        let contentOffset = CGPoint(x: contentOffsetX, y: contentOffsetY)
        return contentOffset
    }
    
    internal func frame(for indexPath: IndexPath) -> CGRect {
        let numberOfItems = self.numberOfItems*indexPath.section + indexPath.item
        let originX: CGFloat = {
            if self.scrollDirection == .vertical {
                return (self.collectionView!.frame.width-self.actualItemSize.width)*0.5
            }
            return self.leadingSpacing + CGFloat(numberOfItems)*self.itemSpacing
        }()
        let originY: CGFloat = {
            if self.scrollDirection == .horizontal {
                return (self.collectionView!.frame.height-self.actualItemSize.height)*0.5
            }
            return self.leadingSpacing + CGFloat(numberOfItems)*self.itemSpacing
        }()
        let origin = CGPoint(x: originX, y: originY)
        let frame = CGRect(origin: origin, size: self.actualItemSize)
        return frame
    }
    
    // MARK:- Notification
    @objc
    fileprivate func didReceiveNotification(notification: Notification) {
        if self.pagerView?.itemSize == .zero {
            self.adjustCollectionViewBounds()
        }
    }
    
    // MARK:- Private functions
    
    fileprivate func commonInit() {
        NotificationCenter.default.addObserver(self, selector: #selector(didReceiveNotification(notification:)), name: UIDevice.orientationDidChangeNotification, object: nil)
    }
    
    fileprivate func adjustCollectionViewBounds() {
        guard let collectionView = self.collectionView, let pagerView = self.pagerView else {
            return
        }
        let currentIndex = pagerView.currentIndex
        let newIndexPath = IndexPath(item: currentIndex, section: pagerView.isInfinite ? self.numberOfSections/2 : 0)
        let contentOffset = self.contentOffset(for: newIndexPath)
        let newBounds = CGRect(origin: contentOffset, size: collectionView.frame.size)
        collectionView.bounds = newBounds
    }
    
    fileprivate func applyTransform(to attributes: LayoutAttributes, with transformer: Transformer?) {
        guard let collectionView = self.collectionView else {
            return
        }
        guard let transformer = transformer else {
            return
        }
        switch self.scrollDirection {
        case .horizontal:
            let ruler = collectionView.bounds.midX
            attributes.position = (attributes.center.x-ruler)/self.itemSpacing
        case .vertical:
            let ruler = collectionView.bounds.midY
            attributes.position = (attributes.center.y-ruler)/self.itemSpacing
        }
        attributes.zIndex = Int(self.numberOfItems)-Int(attributes.position)
        transformer.applyTransform(to: attributes)
    }

}


public class LayoutAttributes: UICollectionViewLayoutAttributes {

    public var position: CGFloat = 0
    
    public override func isEqual(_ object: Any?) -> Bool {
        guard let object = object as? LayoutAttributes else {
            return false
        }
        var isEqual = super.isEqual(object)
        isEqual = isEqual && (position == object.position)
        return isEqual
    }
    
    public override func copy(with zone: NSZone? = nil) -> Any {
        let copy = super.copy(with: zone) as! LayoutAttributes
        copy.position = position
        return copy
    }
    
}


@objc
public enum TransformerType: Int {
    case crossFading
    case zoomOut
    case depth
    case overlap
    case linear
    case coverFlow
    case ferrisWheel
    case invertedFerrisWheel
    case cubic
}

public class Transformer: NSObject {
    
    open internal(set) weak var pagerView: PageView?
    open internal(set) var type: TransformerType
    
    @objc open var minimumScale: CGFloat = 0.65
    @objc open var minimumAlpha: CGFloat = 0.6
    
    @objc
    public init(type: TransformerType) {
        self.type = type
        switch type {
        case .zoomOut:
            self.minimumScale = 0.85
        case .depth:
            self.minimumScale = 0.5
        default:
            break
        }
    }
    
    // Apply transform to attributes - zIndex: Int, frame: CGRect, alpha: CGFloat, transform: CGAffineTransform or transform3D: CATransform3D.
    open func applyTransform(to attributes: LayoutAttributes) {
        guard let pagerView = self.pagerView else {
            return
        }
        let position = attributes.position
        let scrollDirection = pagerView.scrollDirection
        let itemSpacing = (scrollDirection == .horizontal ? attributes.bounds.width : attributes.bounds.height) + self.proposedInteritemSpacing()
        switch self.type {
        case .crossFading:
            var zIndex = 0
            var alpha: CGFloat = 0
            var transform = CGAffineTransform.identity
            switch scrollDirection {
            case .horizontal:
                transform.tx = -itemSpacing * position
            case .vertical:
                transform.ty = -itemSpacing * position
            }
            if (abs(position) < 1) { // [-1,1]
                // Use the default slide transition when moving to the left page
                alpha = 1 - abs(position)
                zIndex = 1
            } else { // (1,+Infinity]
                // This page is way off-screen to the right.
                alpha = 0
                zIndex = Int.min
            }
            attributes.alpha = alpha
            attributes.transform = transform
            attributes.zIndex = zIndex
        case .zoomOut:
            var alpha: CGFloat = 0
            var transform = CGAffineTransform.identity
            switch position {
            case -CGFloat.greatestFiniteMagnitude ..< -1 : // [-Infinity,-1)
                // This page is way off-screen to the left.
                alpha = 0
            case -1 ... 1 :  // [-1,1]
                // Modify the default slide transition to shrink the page as well
                let scaleFactor = max(self.minimumScale, 1 - abs(position))
                transform.a = scaleFactor
                transform.d = scaleFactor
                switch scrollDirection {
                case .horizontal:
                    let vertMargin = attributes.bounds.height * (1 - scaleFactor) / 2;
                    let horzMargin = itemSpacing * (1 - scaleFactor) / 2;
                    transform.tx = position < 0 ? (horzMargin - vertMargin*2) : (-horzMargin + vertMargin*2)
                case .vertical:
                    let horzMargin = attributes.bounds.width * (1 - scaleFactor) / 2;
                    let vertMargin = itemSpacing * (1 - scaleFactor) / 2;
                    transform.ty = position < 0 ? (vertMargin - horzMargin*2) : (-vertMargin + horzMargin*2)
                }
                // Fade the page relative to its size.
                alpha = self.minimumAlpha + (scaleFactor-self.minimumScale)/(1-self.minimumScale)*(1-self.minimumAlpha)
            case 1 ... CGFloat.greatestFiniteMagnitude :  // (1,+Infinity]
                // This page is way off-screen to the right.
                alpha = 0
            default:
                break
            }
            attributes.alpha = alpha
            attributes.transform = transform
        case .depth:
            var transform = CGAffineTransform.identity
            var zIndex = 0
            var alpha: CGFloat = 0.0
            switch position {
            case -CGFloat.greatestFiniteMagnitude ..< -1: // [-Infinity,-1)
                // This page is way off-screen to the left.
                alpha = 0
                zIndex = 0
            case -1 ... 0:  // [-1,0]
                // Use the default slide transition when moving to the left page
                alpha = 1
                transform.tx = 0
                transform.a = 1
                transform.d = 1
                zIndex = 1
            case 0 ..< 1: // (0,1)
                // Fade the page out.
                alpha = CGFloat(1.0) - position
                // Counteract the default slide transition
                switch scrollDirection {
                case .horizontal:
                    transform.tx = itemSpacing * -position
                case .vertical:
                    transform.ty = itemSpacing * -position
                }
                // Scale the page down (between minimumScale and 1)
                let scaleFactor = self.minimumScale
                    + (1.0 - self.minimumScale) * (1.0 - abs(position));
                transform.a = scaleFactor
                transform.d = scaleFactor
                zIndex = 0
            case 1 ... CGFloat.greatestFiniteMagnitude: // [1,+Infinity)
                // This page is way off-screen to the right.
                alpha = 0
                zIndex = 0
            default:
                break
            }
            attributes.alpha = alpha
            attributes.transform = transform
            attributes.zIndex = zIndex
        case .overlap,.linear:
            guard scrollDirection == .horizontal else {
                // This type doesn't support vertical mode
                return
            }
            let scale = max(1 - (1-self.minimumScale) * abs(position), self.minimumScale)
            let transform = CGAffineTransform(scaleX: scale, y: scale)
            attributes.transform = transform
            let alpha = (self.minimumAlpha + (1-abs(position))*(1-self.minimumAlpha))
            attributes.alpha = alpha
            let zIndex = (1-abs(position)) * 10
            attributes.zIndex = Int(zIndex)
        case .coverFlow:
            guard scrollDirection == .horizontal else {
                // This type doesn't support vertical mode
                return
            }
            let position = min(max(-position,-1) ,1)
            let rotation = sin(position*(.pi)*0.5)*(.pi)*0.25*1.5
            let translationZ = -itemSpacing * 0.5 * abs(position)
            var transform3D = CATransform3DIdentity
            transform3D.m34 = -0.002
            transform3D = CATransform3DRotate(transform3D, rotation, 0, 1, 0)
            transform3D = CATransform3DTranslate(transform3D, 0, 0, translationZ)
            attributes.zIndex = 100 - Int(abs(position))
            attributes.transform3D = transform3D
        case .ferrisWheel, .invertedFerrisWheel:
            guard scrollDirection == .horizontal else {
                // This type doesn't support vertical mode
                return
            }
            // http://ronnqvi.st/translate-rotate-translate/
            var zIndex = 0
            var transform = CGAffineTransform.identity
            switch position {
            case -5 ... 5:
                let itemSpacing = attributes.bounds.width+self.proposedInteritemSpacing()
                let count: CGFloat = 14
                let circle: CGFloat = .pi * 2.0
                let radius = itemSpacing * count / circle
                let ty = radius * (self.type == .ferrisWheel ? 1 : -1)
                let theta = circle / count
                let rotation = position * theta * (self.type == .ferrisWheel ? 1 : -1)
                transform = transform.translatedBy(x: -position*itemSpacing, y: ty)
                transform = transform.rotated(by: rotation)
                transform = transform.translatedBy(x: 0, y: -ty)
                zIndex = Int((4.0-abs(position)*10))
            default:
                break
            }
            attributes.alpha = abs(position) < 0.5 ? 1 : self.minimumAlpha
            attributes.transform = transform
            attributes.zIndex = zIndex
        case .cubic:
            switch position {
            case -CGFloat.greatestFiniteMagnitude ... -1:
                attributes.alpha = 0
            case -1 ..< 1:
                attributes.alpha = 1
                attributes.zIndex = Int((1-position) * CGFloat(10))
                let direction: CGFloat = position < 0 ? 1 : -1
                let theta = position * .pi * 0.5 * (scrollDirection == .horizontal ? 1 : -1)
                let radius = scrollDirection == .horizontal ? attributes.bounds.width : attributes.bounds.height
                var transform3D = CATransform3DIdentity
                transform3D.m34 = -0.002
                switch scrollDirection {
                case .horizontal:
                    // ForwardX -> RotateY -> BackwardX
                    attributes.center.x += direction*radius*0.5 // ForwardX
                    transform3D = CATransform3DRotate(transform3D, theta, 0, 1, 0) // RotateY
                    transform3D = CATransform3DTranslate(transform3D,-direction*radius*0.5, 0, 0) // BackwardX
                case .vertical:
                    // ForwardY -> RotateX -> BackwardY
                    attributes.center.y += direction*radius*0.5 // ForwardY
                    transform3D = CATransform3DRotate(transform3D, theta, 1, 0, 0) // RotateX
                    transform3D = CATransform3DTranslate(transform3D,0, -direction*radius*0.5, 0) // BackwardY
                }
                attributes.transform3D = transform3D
            case 1 ... CGFloat.greatestFiniteMagnitude:
                attributes.alpha = 0
            default:
                attributes.alpha = 0
                attributes.zIndex = 0
            }
        }
    }
    
    // An interitem spacing proposed by transformer class. This will override the default interitemSpacing provided by the pager view.
    open func proposedInteritemSpacing() -> CGFloat {
        guard let pagerView = self.pagerView else {
            return 0
        }
        let scrollDirection = pagerView.scrollDirection
        switch self.type {
        case .overlap:
            guard scrollDirection == .horizontal else {
                return 0
            }
            return pagerView.itemSize.width * -self.minimumScale * 0.6
        case .linear:
            guard scrollDirection == .horizontal else {
                return 0
            }
            return pagerView.itemSize.width * -self.minimumScale * 0.2
        case .coverFlow:
            guard scrollDirection == .horizontal else {
                return 0
            }
            return -pagerView.itemSize.width * sin(.pi*0.25*0.25*3.0)
        case .ferrisWheel,.invertedFerrisWheel:
            guard scrollDirection == .horizontal else {
                return 0
            }
            return -pagerView.itemSize.width * 0.15
        case .cubic:
            return 0
        default:
            break
        }
        return pagerView.interitemSpacing
    }
    
}
