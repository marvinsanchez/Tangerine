import {FormlyFieldConfig} from 'ng-formly';

export class TangerineFormCard {
    id = '';
    title: String = undefined;
    subtitle: String = undefined;
    image: String = undefined;
    avatarImage: String = undefined;
    fields: FormlyFieldConfig;
    showSubmitButton = false;
    model: any = {};
    status = '';
    skip =  false;
    logic = '';
}
