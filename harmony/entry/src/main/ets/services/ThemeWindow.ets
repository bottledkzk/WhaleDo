import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { themeColors } from '../model/AppTheme';

export class ThemeWindow {
  private static epoch:number=0;
  static async apply(context:common.UIAbilityContext,dark:boolean,tone:string='whale'):Promise<void> {
    const epoch=++ThemeWindow.epoch,main=await window.getLastWindow(context);
    if(epoch!==ThemeWindow.epoch){return;}
    const colors=themeColors(dark,tone);
    main.setWindowBackgroundColor(colors.surface);
    await main.setWindowSystemBarProperties({statusBarColor:colors.paper,navigationBarColor:colors.surface,statusBarContentColor:colors.ink,navigationBarContentColor:colors.ink});
  }
}
