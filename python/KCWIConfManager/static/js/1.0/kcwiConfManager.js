     angular.module('myApp', [])
            .controller('HomeCtrl', function($scope, $http) {

                // initial settings
                $scope.info = {};
		$scope.showAdd = true;
                $scope.showOption = false;
                $scope.filters=['KBlue','None'];
                $scope.gratings=['BL','BM','BH1','BH2','BH3','None'];
                $scope.slicers=['Small','Medium','Large','FPCam'];
                $scope.maskpositions=['Open','Mask'];
                $scope.progname = "";
		
		// FUNCTIONS FOR STATE FILES
		
		// display content
		$scope.showContent = function($fileContent){
		    $scope.content = $fileContent;
		    console.log("File content updated");
		}

		// send the file to the backend to be uploaded to the database
		$scope.loadConfiguration = function(){
                    $scope.info.progname = $scope.progname;
                    $scope.fileName = document.getElementById("statefile").files[0].name;
		    $http({
		  	method: 'POST',
		  	url:'/sendFile',
		  	data: {file:$scope.content,progname:$scope.info.progname, filename:$scope.fileName}
		    }).then(function(response) {
			$scope.message="";
			$scope.content="";
		  	$scope.showlist();
		  	//$('#addPopUp').modal('hide')
		  	$scope.info = {}
			$scope.message=response.data.message
		    }, function(error) {
		  	console.log(error);
		    });
		}


                // triggers an action when the Enter key is pressed
                $scope.keyEnter = function(keyEvent) {
                    if (keyEvent.which === 13) {
                        $('#progPopUp').modal('hide')
                        $scope.showlist();
                    }
                }

		// save all the state files
		$scope.saveAll = function(){
		    $http({
			method: 'POST',
			url: '/saveAllConfigurations',
			data: {progname: $scope.progname}
			});
		    }

                // GET initial configuration list
                $scope.showlist = function(){
		    $http({
		  	method: 'POST',
		  	url: '/getConfigurationList',
                        data: {progname:$scope.progname}
		    }).then(function(response) {
		  	$scope.configurations = response.data;
		  	console.log('mm',$scope.configurations);
		    }, function(error) {
		  	console.log(error);
		    });
		}

                // set default detector values
                $scope.DefaultDetector = function(){
                   $scope.info.binningb="2,2";
                   $scope.info.ccdmodeb=0;
                   $scope.info.gainmulb=10;
                   $scope.info.ampmodeb=9;
                   }

                // set default cal unit values
                $scope.DefaultCalUnit = function(){
                   $scope.info.cal_mirror="Sky";
                   $scope.info.polarizer="Sky";
                   }

                // add a new configuration
		$scope.addConfiguration = function(){
                    $scope.info.progname = $scope.progname;
		    $http({
		  	method: 'POST',
		  	url:'/addConfiguration',
		  	data: {info:$scope.info}
		    }).then(function(response) {
			$scope.message="";
		  	$scope.showlist();
		  	$('#addPopUp').modal('hide')
		  	$scope.info = {}
		    }, function(error) {
		  	console.log(error);
		    });
		}
                // controls the "Add configuration" popup
		$scope.showAddPopUp = function(){
		    $scope.showAdd = true;
		    $scope.info = {};
		    $('#addPopUp').modal('show')
		}

                // edit an existing configuration
		$scope.editConfiguration = function(id){
		    $scope.info.id = id;
		    $scope.showAdd = false;
		    $http({
		  	method: 'POST',
		  	url: '/getConfiguration',
		  	data: {id:$scope.info.id}
		    }).then(function(response) {
			$scope.message="";
		  	console.log(response);
		  	$scope.info = response.data;
		  	$('#addPopUp').modal('show')
		    }, function(error) {
		  	console.log(error);
		    });
		}

                // duplicate an existing configuration
		$scope.duplicateConfiguration = function(id){
		    $scope.info.id = id;
		    $scope.showAdd = false;
		    $http({
		  	method: 'POST',
		  	url: '/getConfiguration',
		  	data: {id:$scope.info.id}
		    }).then(function(response) {
			$scope.message="";
		  	console.log(response);
		  	$scope.info = response.data;
		  	$scope.addConfiguration()
		    }, function(error) {
		  	console.log(error);
		    });
		}

                // edit an existing configuration (DETECTOR only)
		$scope.editDetector = function(id){
		    $scope.info.id = id;
		    $http({
		  	method: 'POST',
		  	url: '/getConfiguration',
		  	data: {id:$scope.info.id}
		    }).then(function(response) {
			$scope.message="";
		  	console.log(response);
		  	$scope.info = response.data;
		  	$('#detectorPopUp').modal('show')
		    }, function(error) {
		  	console.log(error);
		    });
		}
                // edit an existing configuration (CAL UNIT only)
		$scope.editCalunit = function(id){
		    $scope.info.id = id;
		    $http({
		  	method: 'POST',
		  	url: '/getConfiguration',
		  	data: {id:$scope.info.id}
		    }).then(function(response) {
			$scope.message="";
		  	console.log(response);
		  	$scope.info = response.data;
		  	$('#calunitPopUp').modal('show')
		    }, function(error) {
		  	console.log(error);
		    });
		}
                // post the updated configuration
		$scope.updateConfiguration = function(id){
		    $http({
		  	method: 'POST',
		  	url: '/updateConfiguration',
		  	data: {info:$scope.info}
		    }).then(function(response) {
			$scope.message="";
		  	console.log(response.data);
		  	$scope.showlist();
		  	$('#addPopUp').modal('hide')
                        $('#detectorPopUp').modal('hide')
                        $('#calunitPopUp').modal('hide')
		    }, function(error) {
		  	console.log(error);
		    });
		}

                // controls the "Select program" popup
                $scope.showProgPopUp = function(){
                    $('#progPopUp').modal('show') 
                }
                // controls the "additional options" values
                $scope.showOption = function(){
                    $scope.showOptions=true
                }
                // controls the "execute" popup
		$scope.showRunPopUp = function(id){

		    $scope.info.id = id;
		    $scope.run = {};
		    $http({
		  	method: 'POST',
		  	url: '/getConfiguration',
		  	data: {id:$scope.info.id}
		    }).then(function(response) {
			$scope.message="";
		  	console.log(response);
		  	$scope.run = response.data;
		  	$scope.run.isRoot = false;
		  	$('#runPopUp').modal('show');
		    }, function(error) {
		  	console.log(error);
		    });
		}

                // delete an existing configuration
		$scope.deleteConfiguration = function(){
		    $http({
		  	method: 'POST',
		  	url: '/deleteConfiguration',
		  	data: {id:$scope.deleteConfigurationId}
		    }).then(function(response) {
			$scope.message="";
		  	console.log(response.data);
		  	$scope.deleteConfigurationId = '';
		  	$scope.showlist();
		  	$('#deleteConfirm').modal('hide')
		    }, function(error) {
		  	console.log(error);
		    });
		}
                // controls the "confirm delete" popup
		$scope.confirmDelete = function(id){
		    $scope.deleteConfigurationId = id;
		    $('#deleteConfirm').modal('show');
		}

		// save configuration
		$scope.saveConfiguration = function(id){
		    $scope.info.id = id
		    $http({
			method: 'POST',
			url: '/saveConfiguration',
			data: {id:$scope.info.id}
			}).then(function(response) {
			    $scope.message="";
			    console.log(response.data);
			    $scope.saveConfigurationId = '';
			    $scope.message = response.data.message
			}, function(error) {
			    console.log(error);
			});
		    }
                // execute configuration
		$scope.executeConfiguration = function(){
		    $http({
		  	method: 'POST',
		  	url: '/executeConfiguration',
		  	data: {id:$scope.executeConfigurationId}
		    }).then(function(response) {
			$scope.message="";
		  	console.log(response.data);
		  	$scope.executeConfigurationId = '';
		  	$('#executeConfirm').modal('hide')
			$scope.message=response.data.message
		    }, function(error) {
		  	console.log(error);
		    });
		}
                // controls the "confirm execution" popup
		$scope.confirmExecute = function(id,statenam){
		    $scope.executeConfigurationId = id;
                    $scope.executeConfigurationName = statenam;
		    $('#executeConfirm').modal('show');
		}

		// Calibrations
                // controls the "select calibrations" popup
		//$scope.runCalsPopup = function(){
		//    $('#runCalsPopup').modal('show')
		//}		
                // calibrate
		//$scope.calibrate = function(){
		///   $http({
		//  	method: 'POST',
		//  	url: '/calibrate',
		//  	data: {state_names:$scope.selected_configurations}
		//    }).then(function(response) {
		//  	$scope.selected_configurations = '';
		//  	$('#runCalsPopup').modal('hide')
		//    }, function(error) {
		//  	console.log(error);
		//    });
		//}

                // show the initial list
		$scope.showlist();
         })
    .directive('onReadFile', function ($parse) {
		    return {
		  	restrict: 'A',
		  	scope: true,
		  	link: function(scope, element, attrs) {
		  	    var fn = $parse(attrs.onReadFile);
            
		  	    element.on('change', function(onChangeEvent) {
		  		var reader = new FileReader();
		  		reader.onload = function(onLoadEvent) {
		  			scope.$apply(function() {
		  				fn(scope, {$fileContent:onLoadEvent.target.result});

		  			});
		  		};
		  		reader.readAsText((onChangeEvent.srcElement || onChangeEvent.target).files[0]);
		  	});
		  	}
		  };
		 });
