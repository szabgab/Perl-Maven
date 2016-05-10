angular.module('PerlMavenApp', []).controller('PerlMavenCtrl', function($scope, $http) {
    //console.log('start ng');
    $scope.search_index = function(word) {
        window.location.href = "/search/" + encodeURIComponent(word);
    };

    $scope.search = function() {
        //console.log('search');
        window.location.href = "/search/" + encodeURIComponent($scope.search_term);
    };
    $scope.autocomplete = function() {
        var query = $scope.search_term;
        //console.log('autocomplete "' + query + '"');
        // allow if it is a single character, as we would like to get suggestions on $ and -
        // but maybe disable if it is a letter or a digit.
        if (query.length < 1) {
            $scope.show_autocomplete = false;
            return;
        }
        $http.get('/autocomplete.json/' + encodeURIComponent(query)).then(
        function(response) {
            //console.log(response.data);
            $scope.autocomplete_results = response.data;
            $scope.show_autocomplete = true;

        },
        function(response) {
            console.log("error");
        });
    };
    $scope.admin_show_details = function() {
        console.log('admin_show_details');
        console.log($scope.admin_search_email);
        if (!$scope.admin_search_email) {
            console.log('report that we need an e-mail');
            return;
        }
        $http({
            method: 'GET',
            url: '/admin/user_info.json?email=' + $scope.admin_search_email
        }).then(function(response) {
            console.log(response.data);
            $scope.people = response.data.people;
        },
        function(response) {
            console.log('error');
        });
    };

    $scope.show_searches = function() {
        $http({
            method: 'GET',
            url: '/admin/searches'
        }).then(function(response) {
            console.log(response.data);
            $scope.admin_searches = response.data;
        },
        function(response) {
            console.log('error');
        });
    };
}).filter('encodeURIComponent', function() {
    return window.encodeURIComponent;
});
