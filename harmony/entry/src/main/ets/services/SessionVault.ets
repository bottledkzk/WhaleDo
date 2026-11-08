import { asset } from '@kit.AssetStoreKit';
import { util } from '@kit.ArkTS';

// Tokens belong to this bundle's system asset store, never the task file or backup.
export class SessionVault {
  private static chain:Promise<void>=Promise.resolve();
  static async write(value:string):Promise<void> {
    const pending=SessionVault.chain.then(()=>SessionVault.persist(value));SessionVault.chain=pending.then(()=>{},()=>{});return pending;
  }
  private static async persist(value:string):Promise<void> {
    const alias=new util.TextEncoder().encodeInto('whaletodo-mobile-session');
    const query:asset.AssetMap=new Map<asset.Tag,asset.Value>();query.set(asset.Tag.ALIAS,alias);
    if(value===''){await asset.remove(query);return;}
    const attributes:asset.AssetMap=new Map<asset.Tag,asset.Value>();attributes.set(asset.Tag.SECRET,new util.TextEncoder().encodeInto(value));
    let exists=false;try{exists=(await asset.query(query)).length>0;}catch{}
    if(exists){await asset.update(query,attributes);}else{attributes.set(asset.Tag.ALIAS,alias);await asset.add(attributes);}
  }
  static async read():Promise<string> {
    const query:asset.AssetMap=new Map<asset.Tag,asset.Value>();query.set(asset.Tag.ALIAS,new util.TextEncoder().encodeInto('whaletodo-mobile-session'));query.set(asset.Tag.RETURN_TYPE,asset.ReturnType.ALL);
    try{const values=await asset.query(query);if(values.length===0){return '';}
      return new util.TextDecoder('utf-8').decodeToString(values[0].get(asset.Tag.SECRET) as Uint8Array);
    }catch{return '';}
  }
}
