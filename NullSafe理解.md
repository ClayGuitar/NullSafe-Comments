关于NullSafe的理解
==============================
关于iOS开发中服务器返回`null`引起的崩溃，我想凡是iOS开发者都应该遇到过上述问题。对`null`值的处理大家想必也是各有心得。今天就说一下GitHub上[NullSafe](https://github.com/nicklockwood/NullSafe)这个类别是如何处理相关崩溃的。  
前提
------------------------------------
### 每个iOS程序猿都都应该知道的：
	+ nil (id)0 Objective-C对象的字面零值
	+ Nil (Class)0 Objective-C类的字面零值
	+ NULL (void *)0 C指针的字面零值
	+ NSNull [NSNull null]用来表示零值的单独的对象  

`OC`中`nil`是一个指向不存在的对象指针，`OC`中的对象定义默认赋值为`nil`，而数组和字典里是不可以有`nil`的，但可以为`[NSNull null]`;另外在框架层面，`Foundation`定义了`NSNull`，即一个类方法`+null`，它返回一个单独的`NSNull`对象。`NSNull`与`nil`以及`NULL`不同，因为它是一个实际的对象，而不是一个零值。  
OC方法调用流程  
----------------------------------------------------  
在此之前先说一下`OC`中的类在`runtime`中是如何表示的。

	//类在runtime中的表示

	struct objc_class {

    Class isa;//指针，顾名思义，表示是一个什么，

    //实例的isa指向类对象，类对象的isa指向元类

	#if !__OBJC2__

    Class super_class;  //指向父类

    const char *name;  //类名

    long version;

    long info;

    long instance_size

    struct objc_ivar_list *ivars //成员变量列表

    struct objc_method_list **methodLists; //方法列表

    struct objc_cache *cache;//缓存

    //一种优化，调用过的方法存入缓存列表，下次调用先找缓存

    struct objc_protocol_list *protocols //协议列表

    #endif

	} OBJC2_UNAVAILABLE;

	/* Use `Class` instead of `struct objc_class *` */
由上面的代码可知，一个类由以上的一些信息构成，有了这些信息`OC`方法的调用就可以正常运行起来。  
`OC`方法的调用实际上就是发送消息`objc_send(id, SEL, ...)`,它首先会在对象的类对象的`cache`，`methodlist`以及父类对象的 `cache`,`methodlist`中依次查找`SEL`对应的`IMP`,如果没有找到且实现了动态方法决议机制就会进行决议,如果没有实现动态方法决议机制或决议失败且实现了消息转发机制就会进入消息转发流程,否则程序  crash 。也就是说如果同时提供了动态方法决议和消息转发,那么动态方法决议先于消息转发,只有当动态方法决议依然无法正确决议`selector`  的实现,才会尝试进行消息转发。流程图如下：   
![OC调用流程](http://o7daudvnt.bkt.clouddn.com/2012112623061619.gif)  
######图一  
![OC动态方法决议机制以及消息转发](http://o7daudvnt.bkt.clouddn.com/231837047638961.png)  
######图二  
###1. 动态方法决议（Method Resolution）
`OC`提供了一种名为动态方法决议的手段，使得我们可以在运行时动态地为一个`selector`提供实现。我们只要实现`+resolveInstanceMethod:`或`+resolveClassMethod:`方法，并在其中为指定的`selector`提供实现即可（通过调用运行时函数`class_addMethod`来添加）。这两个方法都是`NSObject`中的类方法，其原型为：  

	+ (BOOL)resolveClassMethod:(SEL)name;  
	+ (BOOL)resolveInstanceMethod:(SEL)name;
参数`name`是需要被动态决议的`selector`；返回值文档中说是表示动态决议成功与否。在不涉及消息转发的情况下，如果在该函数内为指定的`selector`提供实现，无论返回 YES 还是  NO ，编译运行都是正确的；但如果在该函数内并不真正为`selector`提供实现，无论返回 YES 还是 NO，运行都会 crash，道理很简单，`selector`并没有对应的实现，而又没有实现消息转发。`resolveInstanceMethod`是为对象方法进行决议，而 `resolveClassMethod`是为类方法进行决议。
###2. 消息转发（Message Forwarding）
#####Fast Forwarding
如果目标对象实现`- forwardingTargetForSelector:`方法，系统就会在运行时调用这个方法，只要这个方法返回的不是`nil`或`self`，也会重启消息发送的过程，把这消息转发给其他对象来处理。否则，就会继续`Normal Fowarding`。
#####Normal Forwarding
如果没有使用`Fast Forwarding`来消息转发，最后只有使用`Normal Forwarding`来进行消息转发。它首先调用`methodSignatureForSelector:`方法来获取函数的参数和返回值，如果返回为`nil`，程序会 crash 掉，并抛出`unrecognized selector sent to instance`异常信息。如果返回一个函数签名，系统就会创建一个`NSInvocation`对象并调用`-forwardInvocation:`方法。
###3. 使用场景
在一个函数找不到时，Objective-C提供了三种方式去补救：

1. 调用`resolveInstanceMethod`给个机会让类添加这个实现这个函数

2. 调用`forwardingTargetForSelector`让别的对象去执行这个函数

3. 调用`methodSignatureForSelector`（函数符号制造器）和`forwardInvocation`（函数执行器）灵活的将目标函数以其他形式执行。

如果都不中，调用`doesNotRecognizeSelector`抛出异常。
NullSafe
---------------------------------------
有了以上的知识点，NullSafe的原理自然就一目了然了，就是对查找不到的方法进行最后的拦截处理，遍历所有的类看有没有类中的实例实现了此方法，如果有就返回对应的函数签名并通过`forwardInvocation:`将其执行函数的对象变为`nil`去执行，这样就不会引起崩溃了。
具体注释以及其他请参考我上传的文件[NullSafe-Comments](https://github.com/ClayGuitar/NullSafe-Comments)。
其他
---------------------------------------------------
网上现在也有一些对`null`处理的简单例子，比如：  

	- (void)forwardInvocation:(NSInvocation *)anInvocation {
    anInvocation.target = nil;
    [anInvocation invoke];
	}

	- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector {
    
    NSMethodSignature *sig = [super methodSignatureForSelector:aSelector];
    if (!sig) {
        sig = [NSMethodSignature signatureWithObjCTypes:"^v^c"];
    }
    
    return sig;
	}
这样处理也不是不可以，但可能会造成在开发过程中出现没有实现该方法然而在运行方法调用的时候Xcode也不会崩溃，从而导致开发者在开发过程中较难定位问题。
Final
----------------------------
`-(void)doesNotRecognizeSelector:(SEL)aSelector`方法中，抛出异常。等等，为什么我们不能通过给`NSObject`创建一个 `category`，重写这个方法，在这里处理消息未被处理的情况呀？在苹果的官方文档中，明确提到，“一定不能让这个函数就这么结束掉，必须抛出异常”。除了听官方文档的话，其实在分类中通过重写该方法处理各种消息未被处理的情况，会让这个分类的方法特别长，不利于维护。而且还有个原因，明明方法名叫『无法识别 selector』，其中却是一大堆处理该情况的代码，也很奇怪。

参考文章
------------------------------------------
[继承自NSObject的不常用又很有用的函数（2）](http://www.cnblogs.com/biosli/p/NSObject_inherit_2.html)  
[Objective-C特性：Runtime](http://www.jianshu.com/p/25a319aee33d)
[iOS开发-Runtime详解（简书）](http://www.cnblogs.com/ioshe/p/5489086.html)  
[IOS动态方法决议](http://blog.csdn.net/snmhm1991/article/details/38490601)