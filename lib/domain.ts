import {moduleConfig,allRoles,currencies,type Kind,type Role} from './modules.ts';
export type {Kind,Role} from './modules.ts';
export const kinds=Object.keys(moduleConfig) as Kind[];
export type Profile={id:string;name:string;roles:Role[];active:boolean};
export type ProgrammeMember={program_id:string;user_id:string};
export type RecordItem={id:string;kind:Kind;title:string;status:string;amount:number;date:string;currency?:string;category:string;description:string;assignee:string|null;collaborators?:string[];program_id?:string|null;parent_id?:string|null;created_by:string;created_at:string;updated_at:string;version:number;details:Record<string,unknown>};
export type Notice={id:string;title:string;body:string;read_at:string|null;created_at:string;record_id?:string;event_type?:string};
export type Approval={id:string;record_id:string;record_kind:Kind;title:string;summary:string;amount:number;currency:string;requested_by:string;assigned_to:string|null;status:string;record_version:number;created_at:string};
export const roleLabels:Record<Role,string>={chairperson:'Chairperson',vice_chairperson:'Vice-Chairperson',administrator:'Administrator',secretary:'Secretary',treasurer:'Treasurer',finance_manager:'Finance Manager',finance_officer:'Finance Officer',finance_approver:'Finance Approver',executive_director:'Executive Director',operations_manager:'Operations Manager',programme_manager:'Programme Manager',program_officer:'Programme Officer',case_worker:'Case Worker',donor_relations:'Donor Relations Officer',fundraising_manager:'Fundraising Manager',monitoring_officer:'Monitoring & Evaluation Officer',volunteer_coordinator:'Volunteer Coordinator',volunteer:'Volunteer',auditor:'Auditor / Reviewer'};
export const secretarial=kinds.filter(k=>moduleConfig[k].group==='Secretary');
export const financial=kinds.filter(k=>moduleConfig[k].group==='Finance'||['donation','pledge','campaign'].includes(k));
export const hasRole=(p:Profile,roles:readonly string[])=>p.active&&p.roles.some(r=>roles.includes(r));
export const canRead=(p:Profile,k:Kind)=>hasRole(p,moduleConfig[k].read);
export const canWrite=(p:Profile,k:Kind)=>hasRole(p,moduleConfig[k].write);
export const isManager=(p:Profile)=>hasRole(p,['administrator','executive_director','operations_manager','programme_manager','volunteer_coordinator']);
export const canManageSecretary=(p:Profile)=>hasRole(p,['secretary','administrator']);
export function canReadRecord(p:Profile,r:RecordItem,members:ProgrammeMember[]=[]){
 if(!canRead(p,r.kind))return false;
 if(secretarial.includes(r.kind))return canManageSecretary(p);
 const own=r.created_by===p.id||r.assignee===p.id||(r.collaborators||[]).includes(p.id);
 const inProgramme=!!r.program_id&&members.some(m=>m.program_id===r.program_id&&m.user_id===p.id);
 const programOwner=r.kind==='program'&&members.some(m=>m.program_id===r.id&&m.user_id===p.id);
 if(r.kind==='beneficiary')return own||inProgramme;
 if(r.kind==='task'&&r.details.reviewer_id===p.id)return true;
 if(r.kind==='program'&&hasRole(p,['treasurer','finance_manager','finance_officer','auditor']))return true;
 if(r.kind==='task'||r.kind==='document')return own||inProgramme||hasRole(p,['administrator','executive_director','operations_manager']);
 if(moduleConfig[r.kind].group==='Programs')return own||inProgramme||programOwner||hasRole(p,['administrator','executive_director','operations_manager']);
 if(r.kind==='expense')return own||hasRole(p,['treasurer','finance_manager','finance_officer','auditor']);
 if(r.kind==='budget')return own||inProgramme||hasRole(p,['treasurer','finance_manager','finance_officer','auditor']);
 return true;
}
export function canEditRecord(p:Profile,r:RecordItem,members:ProgrammeMember[]=[]){
 if(!canWrite(p,r.kind)||!canReadRecord(p,r,members))return false;
 if(['Approved','Paid','Partly paid','Reconciled','Posted','Received','Settled','Voided','Closed','Completed','Archived','Fulfilled','Distributed'].includes(r.status))return false;
 if(['Submitted','In review'].includes(r.status))return false;
 if(r.kind==='task')return r.created_by===p.id||r.assignee===p.id||(r.collaborators||[]).includes(p.id)||isManager(p);
 return true;
}
export function canApprove(p:Profile,r:RecordItem){return p.active&&p.id!==r.created_by&&(r.kind==='minutes'?hasRole(p,['chairperson','vice_chairperson']):hasRole(p,['chairperson','vice_chairperson','finance_approver','treasurer','finance_manager']));}
export function nextStatuses(r:RecordItem,p:Profile):string[]{
 if(!p.active)return [];
 if(['expense','budget','advance','transfer','retirement','reconciliation'].includes(r.kind)){
  if(['Draft','Returned'].includes(r.status)&&canWrite(p,r.kind))return ['Submitted'];
  if(r.kind==='expense')return [];
  if(['advance','transfer'].includes(r.kind)&&['Paid','Posted'].includes(r.status)&&hasRole(p,['treasurer','finance_manager']))return ['Voided'];
  if(r.kind==='advance'&&r.status==='Approved'&&hasRole(p,['treasurer','finance_manager','finance_officer']))return ['Paid'];
  if(r.kind==='transfer'&&r.status==='Approved'&&hasRole(p,['treasurer','finance_manager','finance_officer']))return ['Posted'];
  if(r.kind==='budget'&&r.status==='Approved'&&hasRole(p,['treasurer','finance_manager']))return ['Closed'];
  return [];
 }
 if(r.kind==='minutes')return ['Draft','Returned'].includes(r.status)&&canWrite(p,r.kind)?['In review']:[];
 if(!canWrite(p,r.kind))return [];
 const transitions:Partial<Record<Kind,Record<string,string[]>>>= {
  program:{Planned:['Approved'],Approved:['Active'],Active:['On hold','Completed'],'On hold':['Active'],Completed:['Archived']},
  activity:{Planned:['Scheduled','Cancelled'],Scheduled:['In progress','Cancelled'],'In progress':['Completed','Cancelled']},
  task:{'To do':['In progress','Cancelled'],'In progress':['Blocked','In review'],Blocked:['In progress'],'In review':['Completed','In progress']},
  meeting:{Draft:['Scheduled','Cancelled'],Scheduled:['Held','Cancelled']},
  resolution:{Proposed:['Adopted','Cancelled'],Adopted:['In progress'],'In progress':['Implemented'],Implemented:['Verified']},
  correspondence:{Draft:['In review','Received'],'In review':['Approved'],Approved:['Sent'],Sent:['Awaiting response','Closed'],Received:['Awaiting response','Closed'],'Awaiting response':['Closed']},
  donation:{Unverified:hasRole(p,['treasurer','finance_manager','finance_officer'])?['Received']:[],Received:hasRole(p,['treasurer','finance_manager'])?['Voided']:[]},
  payment:{Draft:['Paid'],Paid:['Reconciled','Voided'],Reconciled:['Voided']},
  account:{Draft:['Active'],Active:['Closed']},fund:{Active:['Closed']},period:{Open:['Closed']},
  pledge:{Pledged:['Cancelled'],'Partly fulfilled':['Cancelled']},
  in_kind:{Expected:['Received'],Received:['Distributed']},
  campaign:{Draft:['Active'],Active:['Completed','Cancelled']},
  interaction:{Open:['Completed']},indicator:{Active:['Completed']},
  beneficiary:{Open:['Assessed'],Assessed:['Approved'],Approved:['Active'],Active:['Follow-up','Closed'],'Follow-up':['Active','Closed']},
  member:{Active:['Resigned','Suspended'],Suspended:['Active','Resigned']},document:{Draft:['Approved'],Approved:['Archived']},
 };
 const statuses=transitions[r.kind]?.[r.status]||[];
 if(r.kind==='task'&&r.status==='In review'&&r.details.reviewer_id&&r.details.reviewer_id!==p.id)return [];
 if(['payment','account','period'].includes(r.kind)&&!hasRole(p,['treasurer','finance_manager','finance_officer']))return [];
 return statuses;
}
export const initialStatus=(k:Kind)=>moduleConfig[k].initial;
export const validUuid=(v:unknown):v is string=>typeof v==='string'&&/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(v);
const validDate=(s:unknown)=>typeof s==='string'&&/^\d{4}-\d{2}-\d{2}$/.test(s)&&!Number.isNaN(Date.parse(s))&&new Date(s).toISOString().slice(0,10)===s;
export function validateRecord(input:unknown){
 if(!input||typeof input!=='object')throw Error('A record is required.');const v=input as Record<string,any>;
 if(!kinds.includes(v.kind))throw Error('Choose a valid record type.');const kind=v.kind as Kind;
 if(typeof v.title!=='string'||v.title.trim().length<3||v.title.length>180)throw Error('Use a title between 3 and 180 characters.');
 const currency=v.currency||'UGX';if(!(currencies as readonly string[]).includes(currency))throw Error('Choose a supported currency.');
 const amount=Number(v.amount||0),precision=currency==='UGX'?1:100;
 if(!Number.isFinite(amount)||amount<0||amount>1e12||Math.abs(Math.round(amount*precision)-amount*precision)>0.001)throw Error('Enter a valid amount for this currency.');
 if(!validDate(v.date))throw Error('Choose a valid date.');if(typeof v.description!=='string'||v.description.length>20000)throw Error('Description is too long.');
 if(typeof v.category!=='string'||v.category.length>100)throw Error('Category is too long.');
 for(const key of ['assignee','program_id','parent_id'])if(v[key]!=null&&v[key]!==''&&!validUuid(v[key]))throw Error('Choose a valid linked record or team member.');
 const collaborators=v.collaborators||[];if(!Array.isArray(collaborators)||collaborators.length>30||collaborators.some(x=>!validUuid(x)))throw Error('Choose valid collaborators.');
 const details:Record<string,unknown>={};const supplied=v.details||{};if(!supplied||typeof supplied!=='object'||Array.isArray(supplied))throw Error('Invalid form details.');
 for(const field of moduleConfig[kind].fields){const value=supplied[field.key];if(value===undefined||value===null||value==='')continue;
  if(field.type==='number'){if(!Number.isFinite(Number(value))||Math.abs(Number(value))>1e12)throw Error(field.label+' must be a valid number.');details[field.key]=Number(value);}
  else if(field.type==='checkbox'){if(typeof value!=='boolean')throw Error('Invalid '+field.label);details[field.key]=value;}
  else if(field.type==='rows'){if(!Array.isArray(value)||value.length>50||value.some(row=>!Array.isArray(row)||row.length!==(field.columns||[]).length||row.some(cell=>typeof cell!=='string'||cell.length>2000)))throw Error('Invalid '+field.label);details[field.key]=value;}
  else if(field.type==='people'){if(Array.isArray(value)){if(value.length>100||value.some(x=>!validUuid(x)))throw Error('Invalid '+field.label);}else if(!validUuid(value))throw Error('Invalid '+field.label);details[field.key]=value;}
  else if(field.type==='record'){if(!validUuid(value))throw Error('Invalid '+field.label);details[field.key]=value;}
  else {if(typeof value!=='string'||value.length>10000)throw Error('Invalid '+field.label);if(field.type==='date'&&!validDate(value))throw Error('Invalid '+field.label);if(field.type==='datetime'&&Number.isNaN(Date.parse(value)))throw Error('Invalid '+field.label);if(field.options&&!field.options.includes(value))throw Error('Invalid '+field.label);if(field.type==='email'&&!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value))throw Error('Invalid email.');details[field.key]=value;}
 }
 return {kind,title:v.title.trim(),amount,currency,date:v.date,description:v.description,category:v.category,assignee:v.assignee||null,program_id:v.program_id||null,parent_id:v.parent_id||null,collaborators:Array.from(new Set(collaborators)) as string[],details};
}
export const money=(n:number,currency='UGX')=>new Intl.NumberFormat('en-UG',{style:'currency',currency,maximumFractionDigits:currency==='UGX'?0:2}).format(n);
export const shortDate=(s:string)=>new Intl.DateTimeFormat('en-GB',{day:'numeric',month:'short',year:'numeric',timeZone:'Africa/Kampala'}).format(new Date(s));
export const today=()=>new Intl.DateTimeFormat('en-CA',{timeZone:'Africa/Kampala',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());
export {allRoles};
