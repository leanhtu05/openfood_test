import 'package:flutter/material.dart';

class DraggableFloatingActionButton extends StatefulWidget {
  final Widget child;
  final Offset initialOffset;
  final VoidCallback onPressed;
  final Color backgroundColor;
  final double buttonSize;
  final EdgeInsets padding;

  const DraggableFloatingActionButton({
    Key? key,
    required this.child,
    required this.initialOffset,
    required this.onPressed,
    this.backgroundColor = Colors.blue,
    this.buttonSize = 56.0,
    this.padding = const EdgeInsets.all(16.0),
  }) : super(key: key);

  @override
  _DraggableFloatingActionButtonState createState() => _DraggableFloatingActionButtonState();
}

class _DraggableFloatingActionButtonState extends State<DraggableFloatingActionButton> {
  late Offset _offset;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _offset = widget.initialOffset;
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final safeAreaBottom = MediaQuery.of(context).padding.bottom;
    
    return Stack(
      children: [
        Positioned(
          left: _offset.dx,
          bottom: _offset.dy + safeAreaBottom,
          child: GestureDetector(
            onPanStart: (details) {
              setState(() => _isDragging = true);
            },
            onPanUpdate: (details) {
              setState(() {
                _offset = Offset(
                  _offset.dx + details.delta.dx,
                  _offset.dy - details.delta.dy,
                );
                
                // Ensure the button stays within screen bounds
                if (_offset.dx < widget.padding.left) {
                  _offset = Offset(widget.padding.left, _offset.dy);
                }
                if (_offset.dx > screenSize.width - widget.buttonSize - widget.padding.right) {
                  _offset = Offset(
                    screenSize.width - widget.buttonSize - widget.padding.right,
                    _offset.dy
                  );
                }
                if (_offset.dy < widget.padding.bottom) {
                  _offset = Offset(_offset.dx, widget.padding.bottom);
                }
                if (_offset.dy > screenSize.height - widget.buttonSize - widget.padding.top - safeAreaBottom) {
                  _offset = Offset(
                    _offset.dx,
                    screenSize.height - widget.buttonSize - widget.padding.top - safeAreaBottom
                  );
                }
              });
            },
            onPanEnd: (details) {
              setState(() => _isDragging = false);
            },
            onTap: _isDragging ? null : widget.onPressed,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.8, end: 1.0),
              duration: Duration(milliseconds: 300),
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: _isDragging ? 1.2 : value,
                  child: FloatingActionButton(
                    onPressed: null, // Use the GestureDetector's onTap instead
                    backgroundColor: widget.backgroundColor,
                    child: widget.child,
                    elevation: _isDragging ? 8 : 6,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
} 