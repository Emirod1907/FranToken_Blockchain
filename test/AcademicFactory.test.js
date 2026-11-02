const {expect}=require('chai');
const {ethers}=require('hardhat');
const {deployAcademic}=require('../scripts/deploy-academic');
describe('Publicación de franquicias de usuarios',function(){
 it('publica token y C4, recupera reintentos y rechaza otra configuración o actor',async()=>{
  const m=await deployAcademic({writeManifest:false});const [admin,,,,user]=await ethers.getSigners();
  const factory=await ethers.getContractAt('AcademicProjectFactory',m.factory);const compliance=await ethers.deployContract('FranchiseCompliance',[admin.address]);const key=ethers.id('application-opaque');
  await expect(factory.connect(user).createProject(key,'Proyecto usuario','USR',100,await compliance.getAddress())).to.be.revertedWithCustomError(factory,'OwnableUnauthorizedAccount');
  await factory.createProject(key,'Proyecto usuario','USR',100,await compliance.getAddress());
  const address=await factory.projectToken(key);const c4=await factory.projectInvestment(key);const token=await ethers.getContractAt('AcademicFranchiseToken',address);
  expect(await token.owner()).to.equal(admin.address);expect(await token.issuanceController()).to.equal(c4);expect(await token.projectStatus()).to.equal(1);
  await factory.createProject(key,'Proyecto usuario','USR',100,await compliance.getAddress());expect(await factory.projectToken(key)).to.equal(address);
  await expect(factory.createProject(key,'Proyecto usuario','USR',101,await compliance.getAddress())).to.be.revertedWithCustomError(factory,'InvalidConfiguration');
 });
});
