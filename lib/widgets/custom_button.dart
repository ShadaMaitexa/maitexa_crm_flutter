import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../utils/responsive_helper.dart';

class CustomButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Color? backgroundColor;
  final Color? textColor;
  final double? width;
  final double? height;
  final IconData? icon;
  final bool isOutlined;

  const CustomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.backgroundColor,
    this.textColor,
    this.width,
    this.height,
    this.icon,
    this.isOutlined = false,
  });

  @override
  State<CustomButton> createState() => _CustomButtonState();
}

class _CustomButtonState extends State<CustomButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rippleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _rippleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _animationController.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _animationController.reverse();
  }

  void _onTapCancel() {
    _animationController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final responsiveHeight =
        widget.height ?? ResponsiveHelper.getResponsiveButtonHeight(context);
    final responsiveFontSize = ResponsiveHelper.getResponsiveFontSize(
      context,
      14,
    );
    final responsiveIconSize = ResponsiveHelper.getResponsiveIconSize(
      context,
      16,
    );
    final responsivePadding = ResponsiveHelper.getResponsivePadding(context);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                width: widget.width,
                height: responsiveHeight,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppSizes.radiusM),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(_isHovered ? 0.2 : 0.1),
                      blurRadius: _isHovered ? 15 : 8,
                      offset: Offset(0, _isHovered ? 6 : 4),
                      spreadRadius: _isHovered ? 2 : 0,
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppSizes.radiusM),
                    onTap: widget.onPressed,
                    child: Ink(
                      decoration: BoxDecoration(
                        color: widget.isOutlined
                            ? Colors.transparent
                            : (widget.backgroundColor ?? AppColors.primary),
                        borderRadius: BorderRadius.circular(AppSizes.radiusM),
                        border: widget.isOutlined
                            ? Border.all(
                                color: widget.textColor ?? AppColors.primary,
                                width: 2,
                              )
                            : null,
                        gradient: _isHovered && !widget.isOutlined
                            ? LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  (widget.backgroundColor ?? AppColors.primary)
                                      .withOpacity(0.8),
                                  widget.backgroundColor ?? AppColors.primary,
                                ],
                              )
                            : null,
                      ),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: responsivePadding.horizontal / 2,
                          vertical: responsivePadding.vertical / 2,
                        ),
                        child: Stack(
                          children: [
                            // Ripple effect
                            if (_rippleAnimation.value > 0)
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color:
                                        (widget.isOutlined
                                                ? (widget.textColor ??
                                                      AppColors.primary)
                                                : AppColors.textInverse)
                                            .withOpacity(
                                              0.1 * _rippleAnimation.value,
                                            ),
                                  ),
                                ),
                              ),
                            // Content
                            Center(
                              child: widget.isLoading
                                  ? SizedBox(
                                      width: responsiveIconSize,
                                      height: responsiveIconSize,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              widget.isOutlined
                                                  ? (widget.textColor ??
                                                        AppColors.primary)
                                                  : AppColors.textInverse,
                                            ),
                                      ),
                                    )
                                  : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        if (widget.icon != null) ...[
                                          AnimatedRotation(
                                            duration: const Duration(
                                              milliseconds: 300,
                                            ),
                                            turns: _isHovered ? 0.1 : 0.0,
                                            child: Icon(
                                              widget.icon,
                                              size: responsiveIconSize,
                                              color: widget.isOutlined
                                                  ? (widget.textColor ??
                                                        AppColors.primary)
                                                  : (widget.textColor ??
                                                        AppColors.textInverse),
                                            ),
                                          ),
                                          SizedBox(
                                            width:
                                                responsivePadding.horizontal /
                                                4,
                                          ),
                                        ],
                                        Flexible(
                                          child: AnimatedDefaultTextStyle(
                                            duration: const Duration(
                                              milliseconds: 200,
                                            ),
                                            style: TextStyle(
                                              fontSize: responsiveFontSize,
                                              fontWeight: _isHovered
                                                  ? FontWeight.w600
                                                  : FontWeight.w500,
                                              color: widget.isOutlined
                                                  ? (widget.textColor ??
                                                        AppColors.primary)
                                                  : (widget.textColor ??
                                                        AppColors.textInverse),
                                            ),
                                            child: Text(
                                              widget.text,
                                              textAlign: TextAlign.center,
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 2,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
