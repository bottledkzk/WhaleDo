export const toneIds:string[]=['mono','whale','orange','red','green','pink','purple'];
export const toneLabels:string[]=['黑白调','鲸鱼蓝','暖橙','中国红','青葱绿','温柔粉','高贵紫'];

export class ThemeColors {
  paper:string='';surface:string='';ink:string='';muted:string='';accent:string='';
  tint:string='';line:string='';primary:string='';onPrimary:string='';hero:string='';
}

export function themeColors(dark:boolean,tone:string='whale'):ThemeColors {
  const index=Math.max(0,toneIds.indexOf(tone));
  const c=new ThemeColors();
  c.paper=dark?'#171C20':['#F7F7F8','#F5F7FC','#FCF8F2','#FCF6F5','#F5F9F5','#FCF6F8','#F8F6FC'][index];
  c.surface=dark?'#22292E':['#FCFCFD','#FCFDFF','#FFFCF8','#FFFAF9','#FAFDFA','#FFFAFC','#FDFAFF'][index];
  c.ink=dark?'#F0F3F5':'#26343D';c.muted=dark?'#ADBCC5':'#687A85';
  c.accent=dark?['#DADCE4','#9BBCF4','#F1C18C','#F4AAA3','#A2D2AC','#EDB5CB','#CBB6EA'][index]:
    ['#343841','#3F65A2','#A45E22','#B63D3D','#39784A','#AC5C7D','#79549F'][index];
  c.tint=dark?['#32353C','#233F4B','#443729','#482E30','#293E31','#432F3D','#393247'][index]:
    ['#ECEEF1','#EAF0FC','#FAECD9','#F9E6E4','#E6F1E5','#F9E7EF','#EFE6F7'][index];
  c.line=dark?'#36434A':['#E3E5E9','#DDE5F5','#F0E3D2','#F0DDDA','#DDE9DC','#EEDDE5','#E5DCED'][index];
  c.hero=['#343841','#344F79','#9D5C29','#A93D3D','#376D47','#98526E','#6B4B8E'][index];
  c.primary=dark?c.accent:c.hero;c.onPrimary=dark?'#1B2830':'#FFFFFF';
  return c;
}
