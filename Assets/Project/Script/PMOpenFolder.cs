using System.Collections;
using System.Collections.Generic;
using UnityEngine;



namespace HutongGames.PlayMaker.Actions
{
    public class PMOpenFolder : FsmStateAction
    {
        
        /*[RequiredField]
        [UIHint(UIHint.TextArea)]
        public FsmString Path;*/
    
        public override void OnEnter()
        {
            //System.Diagnostics.Process.Start(Path.Value);
            System.Diagnostics.Process.Start(Application.persistentDataPath);
            Finish();
        }
        

    }
}