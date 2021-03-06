package cn.itamt.utils.inspector.core.structureview {
	import cn.itamt.utils.inspector.core.BaseInspectorPlugin;
	import cn.itamt.utils.inspector.core.IInspector;
	import cn.itamt.utils.inspector.core.InspectTarget;
	import cn.itamt.utils.inspector.events.DisplayItemEvent;
	import cn.itamt.utils.inspector.events.InspectEvent;
	import cn.itamt.utils.inspector.output.InspectorOutPuterManager;
	import cn.itamt.utils.inspector.output.StructureTreeItemInfoOutputer;
	import cn.itamt.utils.inspector.plugins.InspectorPluginId;
	import cn.itamt.utils.inspector.popup.InspectorPopupManager;
	import cn.itamt.utils.inspector.popup.PopupAlignMode;

	import flash.display.DisplayObject;
	import flash.events.Event;
	import flash.events.MouseEvent;
	import flash.events.TextEvent;
	import flash.geom.Point;

	/**
	 * 显示对象结构树显示
	 * @author itamt@qq.com
	 */
	public class StructureView extends BaseInspectorPlugin {
		private var _size : Point = new Point(250, 280);

		public function set size(pt : Point) : void {
			_size = pt.clone();
		}

		public function get size() : Point {
			return _size;
		}

		private var treeView : DisplayObjectTree;
		private var panel : StructureViewPanel;
		// 当前实时查看的对象.
		private var liveTarget : InspectTarget;

		public function StructureView() : void {
			super();

			outputerManager = new InspectorOutPuterManager(new StructureTreeItemInfoOutputer());
		}

		override public function set outputerManager(value : InspectorOutPuterManager) : void {
			this._outputerManager = value;
			StructureElementView.outputerManager = this._outputerManager;
		}

		// ////////////////////////////////////
		// //////实现接口：IInspectorPlugin/////
		// ////////////////////////////////////
		override public function getPluginId() : String {
			return InspectorPluginId.STRUCT_VIEW;
		}

		override public function onRegister(inspector : IInspector) : void {
			super.onRegister(inspector);

			_icon = new StructureViewButton();
		}

		override public function contains(child : DisplayObject) : Boolean {
			if (panel) {
				return panel == child || panel.contains(child);
			} else {
				return false;
			}
		}

		override public function onActive() : void {
			super.onActive();

			this.panel = new StructureViewPanel(size.x, size.y);
			this.treeView = new DisplayObjectTree(this._inspector.stage, StructureElementView);
			this.treeView.filterFun = _inspector.isInspectView;
			this.treeView.lineHeight = 20;
			this.treeView.addEventListener(DisplayItemEvent.OVER, onOverElement, false, 0, true);
			this.treeView.addEventListener(DisplayItemEvent.CLICK, onClickElement, false, 0, true);
			this.panel.addEventListener(MouseEvent.ROLL_OUT, onRollOutPanel, false, 0, true);
			this.panel.addEventListener(Event.CLOSE, onClickClose, false, 0, true);
			this.panel.addEventListener(TextEvent.LINK, onClickLinkTarget);
			this.panel.addEventListener(InspectEvent.REFRESH, onRefresh, false, 0, true);

			this.panel.setTreeView(treeView);
			InspectorPopupManager.popup(this.panel, PopupAlignMode.CENTER);
		}

		override public function onUnActive() : void {
			super.onUnActive();

			InspectorPopupManager.remove(this.panel);

			this.treeView.removeEventListener(DisplayItemEvent.OVER, onOverElement);
			this.treeView.removeEventListener(DisplayItemEvent.CLICK, onClickElement);
			this.panel.removeEventListener(MouseEvent.ROLL_OUT, onRollOutPanel);
			this.panel.removeEventListener(Event.CLOSE, onClickClose);
			this.panel.removeEventListener(TextEvent.LINK, onClickLinkTarget);
			this.panel.removeEventListener(InspectEvent.REFRESH, onRefresh);

			this.panel = null;
			this.treeView = null;
		}

		/**
		 * 查看某个显示对象
		 */
		override public function onInspect($target : InspectTarget) : void {
			var item : DisplayItemData;

			if (this.liveTarget) {
				item = this.treeView.getDisplayItem(liveTarget.displayObject);
				item.onLiveInspect(false);
			}
			// if($target == this.target)return;

			if (this.target) {
				item = this.treeView.getDisplayItem(target.displayObject);
				item.onInspect(false);
			}

			this.target = $target;

			if (this.target && this.target.displayObject) {
				item = this.treeView.getDisplayItem(target.displayObject);
				item.onInspect(true);
				this.treeView.onInspect(target.displayObject);
				this.panel.onInspect((target.displayObject));

				// 面板滚动显示到当前目标对象的区域.
				this.panel.showContentArea(this.treeView.getRendererBoundsByObject(target.displayObject), 0);
			}

			// 实现置顶
			// DisplayObjectTool.swapToTop(panel);
		}

		/**
		 * 当Inspector实时查看某个目标显示对象时
		 */
		override public function onLiveInspect($target : InspectTarget) : void {
			var item : DisplayItemData;
			if ($target == this.liveTarget) return;

			if (this.liveTarget) {
				item = this.treeView.getDisplayItem(this.liveTarget.displayObject);
				item.onLiveInspect(false);
			}

			liveTarget = $target;

			item = this.treeView.getDisplayItem(this.liveTarget.displayObject);
			item.onLiveInspect(true);
			this.treeView.onInspect(liveTarget.displayObject);
			this.panel.onLiveInspect(liveTarget.displayObject);

			// 面板滚动显示到当前目标对象的区域.
			this.panel.showContentArea(this.treeView.getRendererBoundsByObject(liveTarget.displayObject), 0);

			// 实现置顶
			// DisplayObjectTool.swapToTop(panel);
		}

		/**
		 * 开时实时查看
		 */
		override public function onStartLiveInspect() : void {
			if (this.target) {
				var item : DisplayItemData = this.treeView.getDisplayItem(this.target.displayObject);
				item.onInspect(false);
			}
		}

		// ////////////////////////////////////
		// ////////private functions///////////
		// ////////////////////////////////////
		/**
		 * 经过一个树元素时.
		 */
		private function onOverElement(evt : DisplayItemEvent) : void {
			// if(!_inspector.isLiveInspecting)return;
			if (evt.target is StructureElementView) {
				var ele : StructureElementView = evt.target as StructureElementView;
				evt.stopImmediatePropagation();

				this._inspector.liveInspect(ele.data.displayObject);
			}
		}

		/**
		 * 点击一个树元素时.
		 */
		private function onClickElement(evt : DisplayItemEvent) : void {
			// if(!_inspector.isLiveInspecting)return;
			if (evt.target is StructureElementView) {
				var ele : StructureElementView = evt.target as StructureElementView;
				evt.stopImmediatePropagation();

				this._inspector.inspect(ele.data.displayObject);
			}
		}

		/**
		 * 鼠标离开面板时.
		 */
		private function onRollOutPanel(evt : MouseEvent) : void {
			if (!this._inspector.isLiveInspecting) {
				if (target) {
					if (!this.panel.hitTestPoint(evt.stageX, evt.stageY)) {
						this._inspector.inspect(target.displayObject);
					}
				}
			}
		}

		private function onClickLinkTarget(evt : TextEvent) : void {
			var level : uint = uint(evt.text);
			var object : DisplayObject = this.panel.inspectObject;
			while (level--) {
				object = object.parent;
			}

			this._inspector.inspect(object);
		}

		override public function onUpdate(target : InspectTarget = null) : void {
			this.treeView.drawList();
		}

		/**
		 * 玩家单击关闭按钮时
		 */
		private function onClickClose(evt : Event) : void {
			// Debug.trace('[StructureView][onClickClose]');
			this._inspector.pluginManager.unactivePlugin(InspectorPluginId.STRUCT_VIEW);
		}

		/**
		 * 刷新按钮
		 */
		private function onRefresh(evt : Event) : void {
			this.onInspect(this.target);
		}

		/**
		 * 销毁对象
		 */
		public function dispose() : void {
		}
	}
}
