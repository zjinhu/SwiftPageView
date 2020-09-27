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
    
    public override class var layoutAttributesClass: AnyClass {
        return LayoutAttributes.self
    }
    
    fileprivate var pageView: PageView? {
        return collectionView?.superview as? PageView
    }
    
    fileprivate var collectionViewSize: CGSize = .zero
    fileprivate var numberOfSections = 1
    fileprivate var numberOfItems = 0
    fileprivate var actualInteritemSpacing: CGFloat = 0
    fileprivate var actualItemSize: CGSize = .zero
    
    override init() {
        super.init()
        commonInit()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: UIDevice.orientationDidChangeNotification, object: nil)
    }
    
    override public func prepare() {
        guard let collectionView = collectionView, let pageView = pageView else {
            return
        }
        guard needsReprepare || collectionViewSize != collectionView.frame.size else {
            return
        }
        needsReprepare = false
        
        collectionViewSize = collectionView.frame.size

        numberOfSections = pageView.numberOfSections(in: collectionView)
        numberOfItems = pageView.collectionView(collectionView, numberOfItemsInSection: 0)
        actualItemSize = {
            var size = pageView.itemSize
            if size == .zero {
                size = collectionView.frame.size
            }
            return size
        }()
        
        actualInteritemSpacing = {
            if let transformer = pageView.transformer {
                return transformer.proposedInteritemSpacing()
            }
            return pageView.interitemSpacing
        }()
        scrollDirection = pageView.scrollDirection
        leadingSpacing = scrollDirection == .horizontal ? (collectionView.frame.width-actualItemSize.width)*0.5 : (collectionView.frame.height-actualItemSize.height)*0.5
        itemSpacing = (scrollDirection == .horizontal ? actualItemSize.width : actualItemSize.height) + actualInteritemSpacing
        
        contentSize = {
            let numberOfItems = self.numberOfItems*numberOfSections
            switch scrollDirection {
                case .horizontal:
                    var contentSizeWidth: CGFloat = leadingSpacing*2 // Leading & trailing spacing
                    contentSizeWidth += CGFloat(numberOfItems-1)*actualInteritemSpacing // Interitem spacing
                    contentSizeWidth += CGFloat(numberOfItems)*actualItemSize.width // Item sizes
                    let contentSize = CGSize(width: contentSizeWidth, height: collectionView.frame.height)
                    return contentSize
                case .vertical:
                    var contentSizeHeight: CGFloat = leadingSpacing*2 // Leading & trailing spacing
                    contentSizeHeight += CGFloat(numberOfItems-1)*actualInteritemSpacing // Interitem spacing
                    contentSizeHeight += CGFloat(numberOfItems)*actualItemSize.height // Item sizes
                    let contentSize = CGSize(width: collectionView.frame.width, height: contentSizeHeight)
                    return contentSize
            }
        }()
        adjustCollectionViewBounds()
    }
    
    override public var collectionViewContentSize: CGSize {
        return contentSize
    }
    
    override public func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        return true
    }
    
    override public func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        var layoutAttributes = [UICollectionViewLayoutAttributes]()
        guard itemSpacing > 0, !rect.isEmpty else {
            return layoutAttributes
        }
        let rect = rect.intersection(CGRect(origin: .zero, size: contentSize))
        guard !rect.isEmpty else {
            return layoutAttributes
        }
        let numberOfItemsBefore = scrollDirection == .horizontal ? max(Int((rect.minX-leadingSpacing)/itemSpacing),0) : max(Int((rect.minY-leadingSpacing)/itemSpacing),0)
        let startPosition = leadingSpacing + CGFloat(numberOfItemsBefore)*itemSpacing
        let startIndex = numberOfItemsBefore
        var itemIndex = startIndex
        
        var origin = startPosition
        let maxPosition = scrollDirection == .horizontal ? min(rect.maxX,contentSize.width-actualItemSize.width-leadingSpacing) : min(rect.maxY,contentSize.height-actualItemSize.height-leadingSpacing)
        while origin-maxPosition <= max(CGFloat(100.0) * .ulpOfOne * abs(origin+maxPosition), .leastNonzeroMagnitude) {
            let indexPath = IndexPath(item: itemIndex%numberOfItems, section: itemIndex/numberOfItems)
            let attributes = layoutAttributesForItem(at: indexPath) as! LayoutAttributes
            applyTransform(to: attributes, with: pageView?.transformer)
            layoutAttributes.append(attributes)
            itemIndex += 1
            origin += itemSpacing
        }
        return layoutAttributes
        
    }
    
    override public func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        let attributes = LayoutAttributes(forCellWith: indexPath)
        attributes.indexPath = indexPath
        let frame = self.frame(for: indexPath)
        let center = CGPoint(x: frame.midX, y: frame.midY)
        attributes.center = center
        attributes.size = actualItemSize
        return attributes
    }
    
    override public func targetContentOffset(forProposedContentOffset proposedContentOffset: CGPoint, withScrollingVelocity velocity: CGPoint) -> CGPoint {
        guard let collectionView = collectionView, let pageView = pageView else {
            return proposedContentOffset
        }
        var proposedContentOffset = proposedContentOffset
        
        func calculateTargetOffset(by proposedOffset: CGFloat, boundedOffset: CGFloat) -> CGFloat {
            var targetOffset: CGFloat
            if pageView.decelerationDistance == PageView.automaticDistance {
                if abs(velocity.x) >= 0.3 {
                    let vector: CGFloat = velocity.x >= 0 ? 1.0 : -1.0
                    targetOffset = round(proposedOffset/itemSpacing+0.35*vector) * itemSpacing // Ceil by 0.15, rather than 0.5
                } else {
                    targetOffset = round(proposedOffset/itemSpacing) * itemSpacing
                }
            } else {
                let extraDistance = max(pageView.decelerationDistance-1, 0)
                switch velocity.x {
                case 0.3 ... CGFloat.greatestFiniteMagnitude:
                    targetOffset = ceil(collectionView.contentOffset.x/itemSpacing+CGFloat(extraDistance)) * itemSpacing
                case -CGFloat.greatestFiniteMagnitude ... -0.3:
                    targetOffset = floor(collectionView.contentOffset.x/itemSpacing-CGFloat(extraDistance)) * itemSpacing
                default:
                    targetOffset = round(proposedOffset/itemSpacing) * itemSpacing
                }
            }
            targetOffset = max(0, targetOffset)
            targetOffset = min(boundedOffset, targetOffset)
            return targetOffset
        }
        let proposedContentOffsetX: CGFloat = {
            if scrollDirection == .vertical {
                return proposedContentOffset.x
            }
            let boundedOffset = collectionView.contentSize.width-itemSpacing
            return calculateTargetOffset(by: proposedContentOffset.x, boundedOffset: boundedOffset)
        }()
        let proposedContentOffsetY: CGFloat = {
            if scrollDirection == .horizontal {
                return proposedContentOffset.y
            }
            let boundedOffset = collectionView.contentSize.height-itemSpacing
            return calculateTargetOffset(by: proposedContentOffset.y, boundedOffset: boundedOffset)
        }()
        proposedContentOffset = CGPoint(x: proposedContentOffsetX, y: proposedContentOffsetY)
        return proposedContentOffset
    }
    
    // MARK:- Internal functions
    
    internal func forceInvalidate() {
        needsReprepare = true
        invalidateLayout()
    }
    
    internal func contentOffset(for indexPath: IndexPath) -> CGPoint {
        let origin = frame(for: indexPath).origin
        guard let collectionView = collectionView else {
            return origin
        }
        let contentOffsetX: CGFloat = {
            if scrollDirection == .vertical {
                return 0
            }
            let contentOffsetX = origin.x - (collectionView.frame.width*0.5-actualItemSize.width*0.5)
            return contentOffsetX
        }()
        let contentOffsetY: CGFloat = {
            if scrollDirection == .horizontal {
                return 0
            }
            let contentOffsetY = origin.y - (collectionView.frame.height*0.5-actualItemSize.height*0.5)
            return contentOffsetY
        }()
        let contentOffset = CGPoint(x: contentOffsetX, y: contentOffsetY)
        return contentOffset
    }
    
    internal func frame(for indexPath: IndexPath) -> CGRect {
        let numberOfItems = self.numberOfItems*indexPath.section + indexPath.item
        let originX: CGFloat = {
            if scrollDirection == .vertical {
                return (collectionView!.frame.width-actualItemSize.width)*0.5
            }
            return leadingSpacing + CGFloat(numberOfItems)*itemSpacing
        }()
        let originY: CGFloat = {
            if scrollDirection == .horizontal {
                return (collectionView!.frame.height-actualItemSize.height)*0.5
            }
            return leadingSpacing + CGFloat(numberOfItems)*itemSpacing
        }()
        let origin = CGPoint(x: originX, y: originY)
        let frame = CGRect(origin: origin, size: actualItemSize)
        return frame
    }
    
    // MARK:- Notification
    @objc
    fileprivate func didReceiveNotification(notification: Notification) {
        if pageView?.itemSize == .zero {
            adjustCollectionViewBounds()
        }
    }
    
    // MARK:- Private functions
    
    fileprivate func commonInit() {
        #if !os(tvOS)
            NotificationCenter.default.addObserver(self, selector: #selector(didReceiveNotification(notification:)), name: UIDevice.orientationDidChangeNotification, object: nil)
        #endif
    }
    
    fileprivate func adjustCollectionViewBounds() {
        guard let collectionView = collectionView, let pageView = pageView else {
            return
        }
        let currentIndex = pageView.currentIndex
        let newIndexPath = IndexPath(item: currentIndex, section: pageView.isInfinite ? numberOfSections/2 : 0)
        let contentOffset = self.contentOffset(for: newIndexPath)
        let newBounds = CGRect(origin: contentOffset, size: collectionView.frame.size)
        collectionView.bounds = newBounds
    }
    
    fileprivate func applyTransform(to attributes: LayoutAttributes, with transformer: Transformer?) {
        guard let collectionView = collectionView else {
            return
        }
        guard let transformer = transformer else {
            return
        }
        switch scrollDirection {
        case .horizontal:
            let ruler = collectionView.bounds.midX
            attributes.position = (attributes.center.x-ruler)/itemSpacing
        case .vertical:
            let ruler = collectionView.bounds.midY
            attributes.position = (attributes.center.y-ruler)/itemSpacing
        }
        attributes.zIndex = Int(numberOfItems)-Int(attributes.position)
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
    
    public internal(set) weak var pageView: PageView?
    public internal(set) var type: TransformerType
    
    public var minimumScale: CGFloat = 0.65
    public var minimumAlpha: CGFloat = 0.6
    
    @objc
    public init(type: TransformerType) {
        self.type = type
        switch type {
        case .zoomOut:
            minimumScale = 0.85
        case .depth:
            minimumScale = 0.5
        default:
            break
        }
    }
    
    public func applyTransform(to attributes: LayoutAttributes) {
        guard let pageView = pageView else {
            return
        }
        let position = attributes.position
        let scrollDirection = pageView.scrollDirection
        let itemSpacing = (scrollDirection == .horizontal ? attributes.bounds.width : attributes.bounds.height) + proposedInteritemSpacing()
        switch type {
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
                alpha = 1 - abs(position)
                zIndex = 1
            } else { // (1,+Infinity]
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
                alpha = 0
            case -1 ... 1 :  // [-1,1]
                let scaleFactor = max(minimumScale, 1 - abs(position))
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
                alpha = minimumAlpha + (scaleFactor-minimumScale)/(1-minimumScale)*(1-minimumAlpha)
            case 1 ... CGFloat.greatestFiniteMagnitude :  // (1,+Infinity]
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
                alpha = 0
                zIndex = 0
            case -1 ... 0:  // [-1,0]
                alpha = 1
                transform.tx = 0
                transform.a = 1
                transform.d = 1
                zIndex = 1
            case 0 ..< 1: // (0,1)
                alpha = CGFloat(1.0) - position
                switch scrollDirection {
                case .horizontal:
                    transform.tx = itemSpacing * -position
                case .vertical:
                    transform.ty = itemSpacing * -position
                }
                let scaleFactor = minimumScale
                    + (1.0 - minimumScale) * (1.0 - abs(position));
                transform.a = scaleFactor
                transform.d = scaleFactor
                zIndex = 0
            case 1 ... CGFloat.greatestFiniteMagnitude: // [1,+Infinity)
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
                return
            }
            let scale = max(1 - (1-minimumScale) * abs(position), minimumScale)
            let transform = CGAffineTransform(scaleX: scale, y: scale)
            attributes.transform = transform
            let alpha = (minimumAlpha + (1-abs(position))*(1-minimumAlpha))
            attributes.alpha = alpha
            let zIndex = (1-abs(position)) * 10
            attributes.zIndex = Int(zIndex)
        case .coverFlow:
            guard scrollDirection == .horizontal else {
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
                return
            }
            var zIndex = 0
            var transform = CGAffineTransform.identity
            switch position {
            case -5 ... 5:
                let itemSpacing = attributes.bounds.width+proposedInteritemSpacing()
                let count: CGFloat = 14
                let circle: CGFloat = .pi * 2.0
                let radius = itemSpacing * count / circle
                let ty = radius * (type == .ferrisWheel ? 1 : -1)
                let theta = circle / count
                let rotation = position * theta * (type == .ferrisWheel ? 1 : -1)
                transform = transform.translatedBy(x: -position*itemSpacing, y: ty)
                transform = transform.rotated(by: rotation)
                transform = transform.translatedBy(x: 0, y: -ty)
                zIndex = Int((4.0-abs(position)*10))
            default:
                break
            }
            attributes.alpha = abs(position) < 0.5 ? 1 : minimumAlpha
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

    public func proposedInteritemSpacing() -> CGFloat {
        guard let pageView = pageView else {
            return 0
        }
        let scrollDirection = pageView.scrollDirection
        switch type {
        case .overlap:
            guard scrollDirection == .horizontal else {
                return 0
            }
            return pageView.itemSize.width * -minimumScale * 0.6
        case .linear:
            guard scrollDirection == .horizontal else {
                return 0
            }
            return pageView.itemSize.width * -minimumScale * 0.2
        case .coverFlow:
            guard scrollDirection == .horizontal else {
                return 0
            }
            return -pageView.itemSize.width * sin(.pi*0.25*0.25*3.0)
        case .ferrisWheel,.invertedFerrisWheel:
            guard scrollDirection == .horizontal else {
                return 0
            }
            return -pageView.itemSize.width * 0.15
        case .cubic:
            return 0
        default:
            break
        }
        return pageView.interitemSpacing
    }
    
}
