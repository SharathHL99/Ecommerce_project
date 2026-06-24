package com.ecommerce.service.impl;

import com.ecommerce.entity.*;
import com.ecommerce.entity.enums.DiscountType;
import com.ecommerce.entity.enums.OrderStatus;
import com.ecommerce.exception.ResourceNotFoundException;
import com.ecommerce.repository.*;
import com.ecommerce.service.CheckoutService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;

@Service
@RequiredArgsConstructor
@Transactional
public class CheckoutServiceImpl implements CheckoutService {

    private final CartRepository cartRepository;
    private final OrderRepository orderRepository;
    private final OrderItemRepository orderItemRepository;
    private final ProductRepository productRepository;

    @Override
    public Order checkout(Long userId, boolean paymentSuccess) {

        Cart cart = cartRepository.findByUserId(userId)
                .orElseThrow(() ->
                        new ResourceNotFoundException("Cart not found"));

        if (cart.getItems().isEmpty()) {
            throw new RuntimeException("Cart is empty");
        }

        Order order = new Order();
        order.setUser(cart.getUser());

        double total = calculateTotal(cart);

        double discount = calculateDiscount(cart, total);

        double finalAmount = total - discount;

        order.setTotalAmount(BigDecimal.valueOf(finalAmount));

        if (paymentSuccess) {
            order.setStatus(OrderStatus.SUCCESS);
        } else {
            order.setStatus(OrderStatus.FAILED);
        }

        Order savedOrder = orderRepository.save(order);

        for (CartItem item : cart.getItems()) {

            Product product = item.getProduct();

            OrderItem orderItem = new OrderItem();
            orderItem.setOrder(savedOrder);
            orderItem.setProduct(product);
            orderItem.setQuantity(item.getQuantity());
            orderItem.setPrice(product.getPrice());

            orderItemRepository.save(orderItem);

            if (paymentSuccess) {

                product.setStockQuantity(
                        product.getStockQuantity()
                                - item.getQuantity());

                productRepository.save(product);
            }
        }

        cart.getItems().clear();
        cart.setCoupon(null);

        cartRepository.save(cart);

        return savedOrder;
    }

    private double calculateTotal(Cart cart) {

        double total = 0;

        for (CartItem item : cart.getItems()) {

            Product product = item.getProduct();

            if (product.getStockQuantity() < item.getQuantity()) {
                throw new RuntimeException(
                        product.getName() + " out of stock");
            }

            total += product.getPrice().doubleValue()
                    * item.getQuantity();
        }

        return total;
    }

    private double calculateDiscount(
            Cart cart,
            double total) {

        if (cart.getCoupon() == null) {
            return 0;
        }

        Coupon coupon = cart.getCoupon();

        if (coupon.getDiscountType()
                == DiscountType.PERCENTAGE) {

            return total *
                    coupon.getDiscountValue()
                            .doubleValue() / 100;
        }

        return coupon.getDiscountValue()
                .doubleValue();
    }
}