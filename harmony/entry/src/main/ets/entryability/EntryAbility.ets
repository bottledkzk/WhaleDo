import { UIAbility, ConfigurationConstant, Configuration } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { prepareDeviceTime } from '../services/DeviceTime';
export default class EntryAbility extends UIAbility {
  private mainWindow:window.Window|undefined=undefined;
  onForeground():void {AppStorage.setOrCreate('appActive',true);}
  onBackground():void {AppStorage.setOrCreate('appActive',false);}
  onWindowStageCreate(stage:window.WindowStage):void {
    prepareDeviceTime();
    AppStorage.setOrCreate('systemDark',this.context.config.colorMode===ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
    AppStorage.setOrCreate('keyboardVisible',false);
    stage.getMainWindow().then((main:window.Window)=>{this.mainWindow=main;main.setWindowLayoutFullScreen(false);main.on('keyboardHeightChange',(height:number)=>{AppStorage.setOrCreate('keyboardVisible',height>0);});}).catch(()=>{});
    stage.loadContent('pages/Index',(error)=>{if(error.code){console.error(`WhaleToDo page load ${error.code}`);}});
  }
  onWindowStageDestroy():void {try{this.mainWindow?.off('keyboardHeightChange');}catch{}this.mainWindow=undefined;}
  onConfigurationUpdate(configuration:Configuration):void {
    AppStorage.setOrCreate('systemDark',configuration.colorMode===ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
  }
}
